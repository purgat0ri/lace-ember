// Lace — the Lace & Ember top bar and dock.
// Two borderless panels float above windows, each hosting a transparent
// WKWebView that draws the design (web/bar.html, web/dock.html). This file only
// supplies data and actions: BetterStage stages, the front app, battery,
// network, now playing (from Übersicht's cache), dock apps and their icons.
import Cocoa
import WebKit
import IOKit.ps
import Network

let home = FileManager.default.homeDirectoryForCurrentUser
let configURL = home.appendingPathComponent(".config/lace/config.json")
let npCacheURL = home.appendingPathComponent(".cache/lace-ember/np.json")
let stagesURL = home.appendingPathComponent("Library/Application Support/BetterStage/stages.json")

struct Config: Codable {
    var dock: [String] = ["com.apple.finder", "com.apple.Safari", "com.anthropic.claudefordesktop",
                          "com.mitchellh.ghostty", "net.shinyfrog.bear", "com.omnigroup.OmniFocus4",
                          "com.readdle.SparkDesktop", "com.flexibits.fantastical2.mac",
                          "|", "com.apple.Music", "tw.ogdesign.eagle"]
    var dockMode: String = "autohide"      // "autohide" | "pinned"
    var showRunning: Bool = false          // true: unpinned running apps after the pinned ones
    var stageKeyMods: [String] = ["opt"]   // BetterStage "switch to stage N" chord (⌥N)
    var clockApp: String = "com.flexibits.fantastical2.mac"
    init() {}
    // any subset of keys works; missing ones keep their defaults
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let def = Config()
        dock = try c.decodeIfPresent([String].self, forKey: .dock) ?? def.dock
        dockMode = try c.decodeIfPresent(String.self, forKey: .dockMode) ?? def.dockMode
        showRunning = try c.decodeIfPresent(Bool.self, forKey: .showRunning) ?? def.showRunning
        stageKeyMods = try c.decodeIfPresent([String].self, forKey: .stageKeyMods) ?? def.stageKeyMods
        clockApp = try c.decodeIfPresent(String.self, forKey: .clockApp) ?? def.clockApp
    }
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
        layout()
        bar.orderFrontRegardless()
        if config.dockMode == "pinned" { showDock(true) } else { dock.alphaValue = 0; dock.orderFrontRegardless() }

        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification, NSWorkspace.didHideApplicationNotification,
                     NSWorkspace.didUnhideApplicationNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.pushBar(); self?.pushDock() }
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
        if webView === barView { loaded.insert("bar"); pushBar() } else { loaded.insert("dock"); pushDock() }
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

    var stageFlags: CGEventFlags {
        var f: CGEventFlags = []
        for mod in config.stageKeyMods {
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
        if AXIsProcessTrusted() { addStageKeyMonitor(); return }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] t in
            if AXIsProcessTrusted() { t.invalidate(); self?.addStageKeyMonitor() }
        }
    }

    func addStageKeyMonitor() {
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
        let ids = readStages()
        // BetterStage only saves lastActiveStageID now and then, so the stage
        // key presses we see (or send) win until it saves a new value.
        let pref = activeStageID()
        if pref != lastPrefStage { lastPrefStage = pref; localStage = nil }
        let activeN = localStage ?? ((pref.flatMap { ids.firstIndex(of: $0) }).map { $0 + 1 } ?? 0)
        let st: [[String: Any]] = ids.enumerated().map { i, id in
            ["n": i + 1, "name": i < stageNames.count ? stageNames[i] : "", "active": i + 1 == activeN]
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

    func pushDock() {
        guard loaded.contains("dock") else { return }
        let running = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        let runningIDs = Set(running.compactMap { $0.bundleIdentifier })
        let frontID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        var items: [[String: Any]] = []
        var pinned = Set<String>()
        for id in config.dock {
            if id == "|" { items.append(["sep": true]); continue }
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { continue }
            pinned.insert(id)
            items.append(["id": id, "name": FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""),
                          "icon": icon(for: url, id: id), "running": runningIDs.contains(id), "front": id == frontID])
        }
        if config.showRunning {
            let extra = running.filter { app in
                guard let id = app.bundleIdentifier else { return false }
                return !pinned.contains(id) && id != Bundle.main.bundleIdentifier
            }
            if !extra.isEmpty { items.append(["sep": true]) }
            for app in extra {
                guard let id = app.bundleIdentifier, let url = app.bundleURL else { continue }
                items.append(["id": id, "name": app.localizedName ?? id, "icon": icon(for: url, id: id),
                              "running": true, "front": id == frontID])
            }
        }
        while let last = items.last, last["sep"] != nil { items.removeLast() }
        dockView.evaluateJavaScript("window.lace && lace.update(\(json(["items": items])))")
    }

    // MARK: web → actions
    func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let m = message.body as? [String: Any], let type = m["type"] as? String else { return }
        switch type {
        case "open":
            if let id = m["id"] as? String { openApp(id) }
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
            if app.isActive { app.hide() } else { app.unhide(); app.activate(options: []) }
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

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
