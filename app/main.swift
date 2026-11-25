// Lace — the Lace & Ember top bar and dock.
// Two borderless panels float above windows, each hosting a transparent
// WKWebView that draws the design (web/bar.html, web/dock.html). This file only
// supplies data and actions: macOS Spaces (or BetterStage stages), the front
// app, battery, network, now playing (from Übersicht's cache), and the dock's
// apps, their windows on this Space and minimised windows.
import Cocoa
import WebKit
import IOKit.ps
import Network
import ScreenCaptureKit

let home = FileManager.default.homeDirectoryForCurrentUser
let configURL = home.appendingPathComponent(".config/lace/config.json")
let npCacheURL = home.appendingPathComponent(".cache/lace-ember/np.json")
let stagesURL = home.appendingPathComponent("Library/Application Support/BetterStage/stages.json")

// Read-only private SkyLight calls (exported through CoreGraphics) that list
// Spaces per display. No SIP changes needed; switching is done with the
// Mission Control "Switch to Desktop N" shortcuts instead.
@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> Int32
@_silgen_name("CGSCopyManagedDisplaySpaces") func CGSCopyManagedDisplaySpaces(_ cid: Int32) -> CFArray
// The Spaces a window is on (mask 7 = every kind); lets ⌘Tab reach other desktops.
@_silgen_name("CGSCopySpacesForWindows") func CGSCopySpacesForWindows(_ cid: Int32, _ mask: Int32, _ wids: CFArray) -> CFArray?
// The window server id behind an AX window: a stable order for dock tiles.
@_silgen_name("_AXUIElementGetWindow") func _AXUIElementGetWindow(_ el: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

struct Config: Codable {
    var dock: [String] = ["com.apple.finder", "com.apple.Safari", "com.anthropic.claudefordesktop",
                          "com.mitchellh.ghostty", "net.shinyfrog.bear", "com.omnigroup.OmniFocus4",
                          "com.readdle.SparkDesktop", "com.flexibits.fantastical2.mac",
                          "|", "com.apple.Music", "tw.ogdesign.eagle"]
    var dockMode: String = "autohide"      // "autohide" | "pinned"
    var dockContent: String = "windows"    // "windows": one tile per live window | "apps": launcher + running apps
    var showRunning: Bool = true           // unpinned running apps after the pinned ones
    var showMinimised: Bool = true         // minimised windows at the end, like the system Dock
    var stageSource: String = "spaces"     // "spaces" (macOS) | "betterstage"
    var stageKeyMods: [String]? = nil      // chord for "switch to N"; default ⌃ for Spaces, ⌥ for BetterStage
    var clockApp: String = "com.flexibits.fantastical2.mac"
    var switcher: Bool = true              // Lace's own ⌘Tab window switcher instead of the system one
    var switcherAllSpaces: Bool = true     // ⌘Tab lists windows on every desktop, not just this one
    var switcherLayout: String = "list"    // "list": titles down the left, a preview on the right | "tiles"
    init() {}
    // any subset of keys works; missing ones keep their defaults
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let def = Config()
        dock = try c.decodeIfPresent([String].self, forKey: .dock) ?? def.dock
        dockMode = try c.decodeIfPresent(String.self, forKey: .dockMode) ?? def.dockMode
        dockContent = try c.decodeIfPresent(String.self, forKey: .dockContent) ?? def.dockContent
        showRunning = try c.decodeIfPresent(Bool.self, forKey: .showRunning) ?? def.showRunning
        showMinimised = try c.decodeIfPresent(Bool.self, forKey: .showMinimised) ?? def.showMinimised
        stageSource = try c.decodeIfPresent(String.self, forKey: .stageSource) ?? def.stageSource
        stageKeyMods = try c.decodeIfPresent([String].self, forKey: .stageKeyMods)
        clockApp = try c.decodeIfPresent(String.self, forKey: .clockApp) ?? def.clockApp
        switcher = try c.decodeIfPresent(Bool.self, forKey: .switcher) ?? def.switcher
        switcherAllSpaces = try c.decodeIfPresent(Bool.self, forKey: .switcherAllSpaces) ?? def.switcherAllSpaces
        switcherLayout = try c.decodeIfPresent(String.self, forKey: .switcherLayout) ?? def.switcherLayout
    }
    var useSpaces: Bool { stageSource != "betterstage" }
    var keyMods: [String] { stageKeyMods ?? (useSpaces ? ["ctrl"] : ["opt"]) }
    static func load() -> Config {
        guard let d = try? Data(contentsOf: configURL),
              let c = try? JSONDecoder().decode(Config.self, from: d) else { return Config() }
        return c
    }
}

final class Panel: NSPanel {
    init(level: NSWindow.Level) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        self.level = level
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isFloatingPanel = true
        acceptsMouseMovedEvents = true
        becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class FirstMouseWebView: WKWebView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

func makeWebView(page: String, handler: WKScriptMessageHandler) -> WKWebView {
    let cfg = WKWebViewConfiguration()
    cfg.userContentController.add(handler, name: "lace")
    let wv = FirstMouseWebView(frame: .zero, configuration: cfg)
    wv.setValue(false, forKey: "drawsBackground")
    wv.underPageBackgroundColor = .clear
    let web = Bundle.main.resourceURL!.appendingPathComponent("web")
    wv.loadFileURL(web.appendingPathComponent(page), allowingReadAccessTo: web)
    return wv
}

func json(_ obj: Any) -> String {
    guard let d = try? JSONSerialization.data(withJSONObject: obj), let s = String(data: d, encoding: .utf8) else { return "null" }
    return s
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate {
    var config = Config.load()
    let bar = Panel(level: .floating)
    let dock = Panel(level: .floating)
    let switcherPanel = Panel(level: .popUpMenu)
    var switcherView: WKWebView!
    var barView: WKWebView!
    var dockView: WKWebView!
    var dockSize = NSSize(width: 600, height: 96)
    var dockShown = false
    var dockHideAt: Date?
    var iconCache: [String: String] = [:]
    var stages: [String] = []
    var stagesMTime: Date?
    var online = true
    let pathMonitor = NWPathMonitor()
    var loaded = Set<String>()

    func applicationDidFinishLaunching(_ n: Notification) {
        barView = makeWebView(page: "bar.html", handler: self)
        dockView = makeWebView(page: "dock.html", handler: self)
        barView.navigationDelegate = self
        dockView.navigationDelegate = self
        bar.contentView = barView
        dock.contentView = dockView
        switcherView = makeWebView(page: "switcher.html", handler: self)
        switcherView.navigationDelegate = self
        switcherPanel.contentView = switcherView
        switcherPanel.ignoresMouseEvents = true
        switcherPanel.alphaValue = 0
        layout()
        bar.orderFrontRegardless()
        if config.dockMode == "pinned" { showDock(true) } else { dock.alphaValue = 0; dock.orderFrontRegardless() }

        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didHideApplicationNotification,
                     NSWorkspace.didUnhideApplicationNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.pushBar(); self?.pushDock() }
        }
        // keep a preview of the window you just went to, for when it's on another desktop
        ws.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self?.warmPreview() }
        }
        if config.switcher && config.switcherLayout != "tiles" && !CGPreflightScreenCaptureAccess() {
            _ = CGRequestScreenCaptureAccess()   // asks once; without it ⌘Tab falls back to tiles
        }
        ws.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.pushBar(); self?.pushDock()
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.layout() }
        pathMonitor.pathUpdateHandler = { [weak self] p in
            DispatchQueue.main.async { self?.online = (p.status == .satisfied); self?.pushBar() }
        }
        pathMonitor.start(queue: .global(qos: .utility))
        watchStageKeys()

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.pushBar() }
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.trackDockHover() }
        // windows open, close and minimise without a workspace notification:
        // refresh the dock while it's visible
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.dockShown || self.config.dockMode == "pinned" else { return }
            self.pushDock()
        }
    }

    // MARK: layout
    var screen: NSScreen { NSScreen.screens.first ?? NSScreen.main! }

    func layout() {
        let s = screen
        let top = min(s.visibleFrame.maxY, s.frame.maxY)
        bar.setFrame(NSRect(x: s.frame.minX, y: top - 56, width: s.frame.width, height: 56), display: true)
        positionDock()
    }

    func positionDock() {
        let s = screen.frame
        let w = min(dockSize.width, s.width - 40), h = dockSize.height
        let shownY = s.minY, hiddenY = s.minY - h + 2
        let y = (dockShown || config.dockMode == "pinned") ? shownY : hiddenY
        dock.setFrame(NSRect(x: s.midX - w / 2, y: y, width: w, height: h), display: true)
    }

    // MARK: dock autohide
    func trackDockHover() {
        guard config.dockMode != "pinned" else { return }
        let m = NSEvent.mouseLocation, s = screen.frame
        let atEdge = m.y <= s.minY + 4 && abs(m.x - s.midX) < dockSize.width / 2 + 60
        let overDock = dockShown && NSPointInRect(m, dock.frame.insetBy(dx: -10, dy: -10))
        if atEdge || overDock {
            dockHideAt = nil
            if !dockShown { showDock(true) }
        } else if dockShown {
            if dockHideAt == nil { dockHideAt = Date().addingTimeInterval(0.7) }
            if let t = dockHideAt, Date() >= t { showDock(false); dockHideAt = nil }
        }
    }

    func showDock(_ on: Bool) {
        dockShown = on
        let s = screen.frame
        let w = min(dockSize.width, s.width - 40), h = dockSize.height
        let target = NSRect(x: s.midX - w / 2, y: on ? s.minY : s.minY - h + 2, width: w, height: h)
        if on { dock.orderFrontRegardless(); pushDock() }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = on ? 0.32 : 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: on ? .easeOut : .easeIn)
            dock.animator().setFrame(target, display: true)
            dock.animator().alphaValue = on ? 1 : 0
        }
        dockView.evaluateJavaScript("window.lace && lace.shown(\(on))")
    }

    // MARK: data → web
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView === barView { loaded.insert("bar"); pushBar() }
        else if webView === dockView { loaded.insert("dock"); pushDock() }
        else { loaded.insert("switcher") }
    }

    func readStages() -> [String] {
        let mt = (try? FileManager.default.attributesOfItem(atPath: stagesURL.path))?[.modificationDate] as? Date
        if mt != nil && mt == stagesMTime { return stages }
        stagesMTime = mt
        guard let d = try? Data(contentsOf: stagesURL),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let list = o["stages"] as? [[String: Any]] else { stages = []; return stages }
        let sorted = list.sorted { ($0["orderIndex"] as? Int ?? 0) < ($1["orderIndex"] as? Int ?? 0) }
        stages = sorted.compactMap { $0["id"] as? String }
        stageNames = sorted.map { s in
            (s["hasCustomName"] as? Bool ?? false) ? (s["name"] as? String ?? "") : ""
        }
        return stages
    }
    var stageNames: [String] = []
    var lastPrefStage: String?? = .none
    var localStage: Int?
    let stageKeys: [CGKeyCode] = [18, 19, 20, 21, 23, 22, 26, 28, 25] // 1–9

    // Desktops (not full-screen apps) on the primary display, in Mission
    // Control order, and which one is showing. "Switch to Desktop N" counts
    // the same desktops.
    func readSpaces() -> (count: Int, active: Int) {
        let (desktops, cur) = desktopSpaces()
        let active = cur.flatMap { desktops.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
        return (min(desktops.count, 9), active)
    }

    // The main display's desktop Space ids in Mission Control order, and the current one.
    func desktopSpaces() -> (ids: [Int], current: Int?) {
        guard let displays = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()) as? [[String: Any]] else { return ([], nil) }
        var mainUUID = "Main"
        if let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
           let u = CGDisplayCreateUUIDFromDisplayID(n.uint32Value)?.takeRetainedValue() {
            mainUUID = CFUUIDCreateString(nil, u) as String
        }
        let d = displays.first { ($0["Display Identifier"] as? String) == mainUUID }
            ?? displays.first { ($0["Display Identifier"] as? String) == "Main" } ?? displays.first
        guard let d = d, let spaces = d["Spaces"] as? [[String: Any]] else { return ([], nil) }
        let desktops = spaces.filter { ($0["type"] as? Int ?? 0) == 0 }.compactMap { $0["ManagedSpaceID"] as? Int }
        return (desktops, (d["Current Space"] as? [String: Any])?["ManagedSpaceID"] as? Int)
    }

    var stageFlags: CGEventFlags {
        var f: CGEventFlags = []
        for mod in config.keyMods {
            switch mod {
            case "ctrl": f.insert(.maskControl)
            case "opt": f.insert(.maskAlternate)
            case "cmd": f.insert(.maskCommand)
            case "shift": f.insert(.maskShift)
            default: break
            }
        }
        return f
    }

    // Watch for the stage chord typed anywhere (needs Accessibility).
    // A monitor added before the grant never receives events, so wait for the
    // grant (asking once), then add it. No restart needed after allowing Lace.
    func watchStageKeys() {
        if AXIsProcessTrusted() { addStageKeyMonitor(); startSwitcher(); return }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
            if AXIsProcessTrusted() { t.invalidate(); self?.addStageKeyMonitor(); self?.startSwitcher() }
        }
    }

    func addStageKeyMonitor() {
        guard !config.useSpaces else { return }   // Spaces report their own changes
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self = self, let i = self.stageKeys.firstIndex(of: CGKeyCode(e.keyCode)) else { return }
            let want = NSEvent.ModifierFlags(rawValue: UInt(self.stageFlags.rawValue))
                .intersection([.control, .option, .command, .shift])
            guard e.modifierFlags.intersection([.control, .option, .command, .shift]) == want else { return }
            if i < self.stages.count { self.localStage = i + 1; self.pushBar() }
        }
    }

    func activeStageID() -> String? {
        CFPreferencesAppSynchronize("app.betterstage.macos" as CFString)
        return CFPreferencesCopyAppValue("lastActiveStageID" as CFString, "app.betterstage.macos" as CFString) as? String
    }

    func battery() -> [String: Any]? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else { return nil }
        for ps in list {
            guard let d = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
                  let cur = d[kIOPSCurrentCapacityKey] as? Int, let max = d[kIOPSMaxCapacityKey] as? Int, max > 0 else { continue }
            let charging = (d[kIOPSIsChargingKey] as? Bool) ?? false
            let plugged = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            return ["pct": Int(round(Double(cur) / Double(max) * 100)), "charging": charging, "plugged": plugged]
        }
        return nil
    }

    func nowPlaying() -> Any {
        guard let d = try? Data(contentsOf: npCacheURL),
              let attrs = try? FileManager.default.attributesOfItem(atPath: npCacheURL.path),
              let mt = attrs[.modificationDate] as? Date, Date().timeIntervalSince(mt) < 30,
              let o = try? JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed]) else { return NSNull() }
        return o
    }

    func pushBar() {
        guard loaded.contains("bar") else { return }
        var st: [[String: Any]]
        if config.useSpaces {
            let sp = readSpaces()
            st = (0..<sp.count).map { i in ["n": i + 1, "name": "", "active": i + 1 == sp.active] }
        } else {
            let ids = readStages()
            // BetterStage only saves lastActiveStageID now and then, so the stage
            // key presses we see (or send) win until it saves a new value.
            let pref = activeStageID()
            if pref != lastPrefStage { lastPrefStage = pref; localStage = nil }
            let activeN = localStage ?? ((pref.flatMap { ids.firstIndex(of: $0) }).map { $0 + 1 } ?? 0)
            st = ids.enumerated().map { i, id in
                ["n": i + 1, "name": i < stageNames.count ? stageNames[i] : "", "active": i + 1 == activeN]
            }
        }
        let front = NSWorkspace.shared.frontmostApplication
        let state: [String: Any] = [
            "stages": st,
            "app": front?.localizedName ?? "",
            "battery": battery() ?? NSNull(),
            "online": online,
            "np": nowPlaying(),
        ]
        barView.evaluateJavaScript("window.lace && lace.update(\(json(state)))")
    }

    func icon(for url: URL, id: String) -> String {
        if let c = iconCache[id] { return c }
        let img = NSWorkspace.shared.icon(forFile: url.path)
        let size = NSSize(width: 96, height: 96)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 96, pixelsHigh: 96, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        img.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        let s = "data:image/png;base64," + (rep.representation(using: .png, properties: [:])?.base64EncodedString() ?? "")
        iconCache[id] = s
        return s
    }

    // MARK: windows (Accessibility)
    // An app's AX window list holds its windows on the current Space plus its
    // minimised ones, which is exactly what the dock shows.
    struct Win { let el: AXUIElement; let title: String; let minimised: Bool; let wid: CGWindowID }

    func ax<T>(_ el: AXUIElement, _ attr: String) -> T? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success else { return nil }
        return v as? T
    }

    func windows(of app: NSRunningApplication) -> [Win] {
        guard AXIsProcessTrusted() else { return [] }
        let a = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(a, 0.25)   // a hung app must not stall the dock
        guard let list: [AXUIElement] = ax(a, kAXWindowsAttribute) else { return [] }
        return list.compactMap { w in
            let sub: String? = ax(w, kAXSubroleAttribute)
            guard sub == kAXStandardWindowSubrole || sub == kAXDialogSubrole else { return nil }
            let t: String = ax(w, kAXTitleAttribute) ?? ""
            let m: Bool = ax(w, kAXMinimizedAttribute) ?? false
            var wid: CGWindowID = 0
            _ = _AXUIElementGetWindow(w, &wid)
            if !t.isEmpty { titleCache[wid] = t }   // ⌘Tab names windows on other desktops from this
            return Win(el: w, title: t.isEmpty ? (app.localizedName ?? "Window") : t, minimised: m, wid: wid)
        }.sorted { $0.wid < $1.wid }   // creation order, so tiles don't reshuffle on focus
    }

    var winTokens: [String: (AXUIElement, pid_t)] = [:]
    var titleCache: [CGWindowID: String] = [:]
    var mru: [CGWindowID] = []                  // focused windows, most recent first

    func touchMRU(_ wid: CGWindowID) {
        guard wid != 0 else { return }
        mru.removeAll { $0 == wid }
        mru.insert(wid, at: 0)
        if mru.count > 200 { mru.removeLast() }
    }

    func focusedWID() -> CGWindowID {
        guard let f = NSWorkspace.shared.frontmostApplication else { return 0 }
        let a = AXUIElementCreateApplication(f.processIdentifier)
        AXUIElementSetMessagingTimeout(a, 0.25)
        guard let w: AXUIElement = ax(a, kAXFocusedWindowAttribute) else { return 0 }
        var wid: CGWindowID = 0
        _ = _AXUIElementGetWindow(w, &wid)
        return wid
    }

    func raise(_ w: AXUIElement, pid: pid_t) {
        // activate first, then make this window main and raise it, so the app
        // doesn't bring its previous key window back over it
        AXUIElementSetAttributeValue(w, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        NSRunningApplication(processIdentifier: pid)?.activate(options: [])
        AXUIElementSetAttributeValue(w, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(w, kAXRaiseAction as CFString)
    }

    // One tile per live window on this Space, grouped by app in launch order,
    // then minimised windows. Apps without a window here don't appear.
    func pushWindowDock() {
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }
        let front = NSWorkspace.shared.frontmostApplication
        var focused: AXUIElement?
        if let f = front {
            let a = AXUIElementCreateApplication(f.processIdentifier)
            AXUIElementSetMessagingTimeout(a, 0.25)
            focused = ax(a, kAXFocusedWindowAttribute)
            if let w = focused { var wid: CGWindowID = 0; _ = _AXUIElementGetWindow(w, &wid); touchMRU(wid) }
        }
        var live: [[String: Any]] = [], minimised: [[String: Any]] = []
        var tokens: [String: (AXUIElement, pid_t)] = [:]
        for app in running {
            guard let id = app.bundleIdentifier, let url = app.bundleURL else { continue }
            for w in windows(of: app) {
                let tok = "\(app.processIdentifier):\(w.wid)"
                tokens[tok] = (w.el, app.processIdentifier)
                let isFront = app == front && focused.map { CFEqual($0, w.el) } == true
                let e: [String: Any] = ["win": true, "min": w.minimised, "token": tok, "id": id, "name": w.title,
                                        "app": app.localizedName ?? id, "icon": icon(for: url, id: id),
                                        "front": isFront, "hidden": app.isHidden]
                if w.minimised { minimised.append(e) } else { live.append(e) }
            }
        }
        var items = live
        if config.showMinimised && !minimised.isEmpty {
            if !items.isEmpty { items.append(["sep": true]) }
            items += minimised
        }
        winTokens = tokens
        dockView.evaluateJavaScript("window.lace && lace.update(\(json(["items": items])))")
    }

    func pushDock() {
        guard loaded.contains("dock") else { return }
        if config.dockContent != "apps" { pushWindowDock(); return }
        let running = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        let byID = Dictionary(running.compactMap { a in a.bundleIdentifier.map { ($0, a) } }, uniquingKeysWith: { a, _ in a })
        let frontID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        var items: [[String: Any]] = []
        var minimised: [[String: Any]] = []
        var tokens: [String: (AXUIElement, pid_t)] = [:]
        var pinned = Set<String>()

        func entry(id: String, url: URL, name: String) -> [String: Any] {
            var e: [String: Any] = ["id": id, "name": name, "icon": icon(for: url, id: id),
                                    "running": false, "front": id == frontID, "wins": 0, "hidden": false]
            guard let app = byID[id] else { return e }
            let ws = windows(of: app)
            e["running"] = true
            e["hidden"] = app.isHidden
            e["wins"] = ws.filter { !$0.minimised }.count
            for (i, w) in ws.enumerated() where w.minimised {
                let tok = "\(app.processIdentifier):\(i)"
                tokens[tok] = (w.el, app.processIdentifier)
                minimised.append(["min": true, "token": tok, "id": id, "name": w.title, "icon": icon(for: url, id: id)])
            }
            return e
        }

        for id in config.dock {
            if id == "|" { items.append(["sep": true]); continue }
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { continue }
            pinned.insert(id)
            items.append(entry(id: id, url: url, name: FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")))
        }
        if config.showRunning {
            let extra = running.filter { app in
                guard let id = app.bundleIdentifier else { return false }
                return !pinned.contains(id) && id != Bundle.main.bundleIdentifier
            }
            if !extra.isEmpty { items.append(["sep": true]) }
            for app in extra {
                guard let id = app.bundleIdentifier, let url = app.bundleURL else { continue }
                items.append(entry(id: id, url: url, name: app.localizedName ?? id))
            }
        }
        if config.showMinimised && !minimised.isEmpty {
            items.append(["sep": true])
            items += minimised
        }
        while let last = items.last, last["sep"] != nil { items.removeLast() }
        winTokens = tokens
        dockView.evaluateJavaScript("window.lace && lace.update(\(json(["items": items])))")
    }

    // Right-click: the app's windows here and minimised, then Hide / Quit.
    func appMenu(_ id: String) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == id }) else { return }
        let menu = NSMenu()
        menu.appearance = NSAppearance(named: .darkAqua)
        let ws = windows(of: app)
        for w in ws {
            let item = NSMenuItem(title: (w.minimised ? "◇ " : "◆ ") + w.title, action: #selector(menuRaise(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = (w.el, app.processIdentifier) as AnyObject
            menu.addItem(item)
        }
        if !ws.isEmpty { menu.addItem(.separator()) }
        let hide = NSMenuItem(title: app.isHidden ? "Show" : "Hide", action: #selector(menuHide(_:)), keyEquivalent: "")
        let quit = NSMenuItem(title: "Quit", action: #selector(menuQuit(_:)), keyEquivalent: "")
        for i in [hide, quit] { i.target = self; i.representedObject = app; menu.addItem(i) }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
    @objc func menuRaise(_ s: NSMenuItem) {
        if let (w, pid) = s.representedObject as? (AXUIElement, pid_t) { raise(w, pid: pid) }
    }
    @objc func menuHide(_ s: NSMenuItem) {
        guard let a = s.representedObject as? NSRunningApplication else { return }
        if a.isHidden { a.unhide() } else { a.hide() }
    }
    @objc func menuQuit(_ s: NSMenuItem) { (s.representedObject as? NSRunningApplication)?.terminate() }

    // MARK: ⌘Tab switcher
    // A session event tap sees ⌘Tab before the system switcher does and
    // swallows it (Accessibility is enough). Holding ⌘: Tab / ⇧Tab / ← → move,
    // Esc cancels, releasing ⌘ raises the chosen window. Windows on every
    // desktop, most recently used first, then minimised ones. Accessibility
    // only sees this Space's windows, so the others come from the window
    // server; choosing one switches to its desktop (⌃N), then raises it there.
    struct Target { let el: AXUIElement?; let pid: pid_t; let wid: CGWindowID; let space: Int }
    var tap: CFMachPort?
    var switching = false
    var switchList: [Target] = []
    var switchSel = 0
    var switchShown = false

    func startSwitcher() {
        guard config.switcher, tap == nil else { return }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        guard let t = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                        eventsOfInterest: CGEventMask(mask), callback: switcherTapCallback,
                                        userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        tap = t
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
    }

    func handleTap(_ type: CGEventType, _ e: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return Unmanaged.passUnretained(e)
        }
        let f = e.flags, code = e.getIntegerValueField(.keyboardEventKeycode)
        let cmd = f.contains(.maskCommand) && f.intersection([.maskControl, .maskAlternate]).isEmpty
        if type == .keyDown && code == 48 && cmd {                       // Tab
            if !switching { beginSwitch(back: f.contains(.maskShift)) } else { stepSwitch(f.contains(.maskShift) ? -1 : 1) }
            return nil
        }
        if switching {
            if type == .keyUp && code == 48 { return nil }
            if type == .keyDown && code == 53 { endSwitch(commit: false); return nil }        // Esc
            if type == .keyDown && (code == 123 || code == 124) { stepSwitch(code == 123 ? -1 : 1); return nil }
            if type == .flagsChanged && !f.contains(.maskCommand) { endSwitch(commit: true) }
        }
        return Unmanaged.passUnretained(e)
    }

    func beginSwitch(back: Bool) {
        touchMRU(focusedWID())
        // every window the server knows, front to back (other desktops' too)
        let all = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var z: [CGWindowID: Int] = [:]
        for (i, w) in all.enumerated() { if let n = w[kCGWindowNumber as String] as? Int { z[CGWindowID(n)] = i } }
        func rank(_ wid: CGWindowID, _ hidden: Bool) -> Int {
            if let i = mru.firstIndex(of: wid) { return i }
            return (hidden ? 50_000 : 1_000) + (z[wid] ?? 20_000)
        }
        let (desktops, cur) = desktopSpaces()
        let curIdx = cur.flatMap { desktops.firstIndex(of: $0) }.map { $0 + 1 } ?? 0

        var live: [(Int, [String: Any], Target)] = [], mins: [([String: Any], Target)] = []
        var seen = Set<CGWindowID>()
        var apps: [pid_t: (NSRunningApplication, String, URL)] = [:]
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular
            && app.bundleIdentifier != Bundle.main.bundleIdentifier {
            guard let id = app.bundleIdentifier, let url = app.bundleURL else { continue }
            apps[app.processIdentifier] = (app, id, url)
            for w in windows(of: app) {
                seen.insert(w.wid)
                let item: [String: Any] = ["name": w.title, "app": app.localizedName ?? id, "icon": icon(for: url, id: id),
                                           "min": w.minimised, "hidden": app.isHidden]
                let t = Target(el: w.el, pid: app.processIdentifier, wid: w.wid, space: 0)
                if w.minimised { mins.append((item, t)) } else { live.append((rank(w.wid, app.isHidden), item, t)) }
            }
        }

        // windows on the other desktops of the main display
        if config.useSpaces && config.switcherAllSpaces && desktops.count > 1 {
            let cid = CGSMainConnectionID()
            for w in all {
                guard let n = w[kCGWindowNumber as String] as? Int, (w[kCGWindowLayer as String] as? Int) == 0,
                      let pid = (w[kCGWindowOwnerPID as String] as? Int).map({ pid_t($0) }),
                      let (app, id, url) = apps[pid] else { continue }
                let wid = CGWindowID(n)
                guard !seen.contains(wid), (w[kCGWindowAlpha as String] as? Double ?? 1) > 0 else { continue }
                if let b = w[kCGWindowBounds as String] as? [String: Any],
                   (b["Width"] as? Double ?? 0) < 80 || (b["Height"] as? Double ?? 0) < 60 { continue }
                guard let sp = CGSCopySpacesForWindows(cid, 7, [NSNumber(value: wid)] as CFArray) as? [Int],
                      !sp.contains(cur ?? -1),                  // on this desktop too (assigned to all)
                      let idx = sp.compactMap({ desktops.firstIndex(of: $0) }).first.map({ $0 + 1 }),
                      idx != curIdx else { continue }
                seen.insert(wid)
                let name = (w[kCGWindowName as String] as? String).flatMap { $0.isEmpty ? nil : $0 }
                    ?? titleCache[wid] ?? app.localizedName ?? id
                let item: [String: Any] = ["name": name, "app": app.localizedName ?? id, "icon": icon(for: url, id: id),
                                           "min": false, "hidden": app.isHidden, "space": idx]
                live.append((rank(wid, app.isHidden), item, Target(el: nil, pid: pid, wid: wid, space: idx)))
            }
        }

        live.sort { $0.0 < $1.0 }
        let items = live.map { $0.1 } + mins.map { $0.0 }
        switchList = live.map { $0.2 } + mins.map { $0.1 }
        guard !switchList.isEmpty else { return }
        switching = true
        switchSel = switchList.count > 1 ? (back ? switchList.count - 1 : 1) : 0
        let list = listLayout
        if list {
            scFetch = refreshSCWindows()
            let alive = Set(switchList.map { $0.wid })
            previewCache = previewCache.filter { alive.contains($0.key) }
        }
        switcherView.evaluateJavaScript("window.lace && lace.update(\(json(["items": items, "sel": switchSel, "layout": list ? "list" : "tiles"])))")
        showPreview()
        // a quick ⌘Tab flick switches without flashing the panel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self = self, self.switching, !self.switchShown else { return }
            self.switchShown = true
            let s = self.screen.frame
            self.switcherPanel.setFrame(list ? s : NSRect(x: s.minX, y: s.midY - 200, width: s.width, height: 400), display: true)
            self.switcherPanel.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { $0.duration = 0.12; self.switcherPanel.animator().alphaValue = 1 }
        }
    }

    func stepSwitch(_ d: Int) {
        guard !switchList.isEmpty else { return }
        switchSel = (switchSel + d + switchList.count) % switchList.count
        switcherView.evaluateJavaScript("window.lace && lace.select(\(switchSel))")
        showPreview()
    }

    // MARK: previews (ScreenCaptureKit, needs Screen Recording)
    // Only the selected window is captured, at up to 1600×1000 px. Each good
    // capture is cached, because a window on another desktop can come back
    // blank: then the last picture taken while it was visible stands in.
    var previewCache: [CGWindowID: String] = [:]
    var scWindows: [CGWindowID: SCWindow] = [:]
    var scFetch: Task<Void, Never>?
    var listLayout: Bool { config.switcherLayout != "tiles" && CGPreflightScreenCaptureAccess() }

    func refreshSCWindows() -> Task<Void, Never> {
        Task { @MainActor in
            guard let c = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false) else { return }
            var m: [CGWindowID: SCWindow] = [:]
            for w in c.windows { m[w.windowID] = w }
            self.scWindows = m
        }
    }

    func capture(_ wid: CGWindowID) async -> String? {
        guard let w = scWindows[wid], w.frame.width > 1, w.frame.height > 1 else { return nil }
        let cfg = SCStreamConfiguration()
        let k = min(1600 / w.frame.width, 1000 / w.frame.height, 2)
        cfg.width = Int(w.frame.width * k); cfg.height = Int(w.frame.height * k)
        cfg.showsCursor = false
        cfg.ignoreShadowsSingleWindow = true
        guard let img = try? await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: w),
                                                                     configuration: cfg),
              !isBlank(img), let d = NSBitmapImageRep(cgImage: img).representation(using: .jpeg, properties: [.compressionFactor: 0.82])
        else { return nil }
        return "data:image/jpeg;base64," + d.base64EncodedString()
    }

    // a capture of a window macOS isn't drawing: fully transparent or flat black
    func isBlank(_ img: CGImage) -> Bool {
        let n = 12
        var px = [UInt8](repeating: 0, count: n * n * 4)
        guard let ctx = CGContext(data: &px, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return false }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: n, height: n))
        var lit = 0
        for i in stride(from: 0, to: px.count, by: 4) where px[i + 3] > 12 && Int(px[i]) + Int(px[i + 1]) + Int(px[i + 2]) > 24 { lit += 1 }
        return lit < 3
    }

    func pushPreview(_ sel: Int, _ url: String?, final: Bool) {
        switcherView.evaluateJavaScript("window.lace && lace.preview(\(json(["i": sel, "url": url.map { $0 as Any } ?? NSNull(), "final": final])))")
    }

    func showPreview() {
        guard listLayout, switching, switchSel < switchList.count else { return }
        let sel = switchSel, wid = switchList[sel].wid
        pushPreview(sel, previewCache[wid], final: false)
        Task { @MainActor in
            await self.scFetch?.value
            guard self.switching, self.switchSel == sel else { return }
            let url = await self.capture(wid)
            if let url = url { self.previewCache[wid] = url }
            if self.switching && self.switchSel == sel { self.pushPreview(sel, url ?? self.previewCache[wid], final: true) }
        }
    }

    func warmPreview() {
        guard listLayout, !switching else { return }
        let wid = focusedWID()
        guard wid != 0 else { return }
        Task { @MainActor in
            if self.scWindows[wid] == nil { await self.refreshSCWindows().value }
            if let url = await self.capture(wid) { self.previewCache[wid] = url }
        }
    }

    func endSwitch(commit: Bool) {
        guard switching else { return }
        switching = false
        switchShown = false
        switcherPanel.alphaValue = 0
        switcherPanel.orderOut(nil)
        if commit, switchSel < switchList.count {
            let t = switchList[switchSel]
            touchMRU(t.wid)
            if let el = t.el { raise(el, pid: t.pid) } else { raiseAway(t) }
        }
        switchList = []
    }

    // Go to the window's desktop, then raise it once Accessibility can see it.
    func raiseAway(_ t: Target) {
        switchStage(t.space)
        var tries = 0
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            tries += 1
            guard let self = self, let app = NSRunningApplication(processIdentifier: t.pid) else { timer.invalidate(); return }
            if let w = self.windows(of: app).first(where: { $0.wid == t.wid }) {
                timer.invalidate(); self.raise(w.el, pid: t.pid)
            } else if tries > 40 {
                timer.invalidate(); app.activate(options: [])   // couldn't find it: at least bring the app
            }
        }
    }

    // MARK: web → actions
    func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let m = message.body as? [String: Any], let type = m["type"] as? String else { return }
        switch type {
        case "open":
            if let id = m["id"] as? String { openApp(id) }
        case "restore":
            if let t = m["token"] as? String, let (w, pid) = winTokens[t] { raise(w, pid: pid); pushDock() }
        case "menu":
            if let id = m["id"] as? String { appMenu(id) }
        case "stage":
            if let n = m["n"] as? Int { switchStage(n) }
        case "clock":
            openApp(config.clockApp)
        case "music":
            if let app = (nowPlaying() as? [String: Any])?["app"] as? String {
                openApp(app == "Spotify" ? "com.spotify.client" : "com.apple.Music")
            }
        case "size":
            if let w = m["w"] as? Double, let h = m["h"] as? Double {
                dockSize = NSSize(width: ceil(w), height: ceil(h)); positionDock()
            }
        default: break
        }
    }

    func openApp(_ id: String) {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == id }) {
            if app.isActive && !app.isHidden { app.hide(); return }
            app.unhide()
            let ws = windows(of: app)
            if let w = ws.first(where: { !$0.minimised }) {
                app.activate(options: [])
                AXUIElementPerformAction(w.el, kAXRaiseAction as CFString)
            } else if let w = ws.first {
                raise(w.el, pid: app.processIdentifier)      // only minimised windows: bring one back
            } else if let url = app.bundleURL {
                // no window on this Space: a reopen, like clicking it in the system Dock
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
            return
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    func switchStage(_ n: Int) {
        guard n >= 1, n <= stageKeys.count else { return }
        guard AXIsProcessTrusted() else {
            // open the Accessibility pane rather than stacking up system prompts
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            return
        }
        let flags = stageFlags
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: nil, virtualKey: stageKeys[n - 1], keyDown: down)
            e?.flags = flags
            e?.post(tap: .cghidEventTap)
        }
        localStage = n
        pushBar()
    }
}

let switcherTapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    return Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue().handleTap(type, event)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
