# Lace & Ember

A dark, ornate macOS desktop built around one design language: every panel is
the same **block**. That means obsidian glass, a thin bone hairline, a black
outline, gold corner pins and a crimson glow underneath. Colours come from a
storm painting: ink, crimson, ember, gold and bone. The idea of applying one
look everywhere comes from [SekaiPop](https://github.com/Blapples/SekaiPop),
a Hyprland shell. This is the macOS version, built from Mac tools.

Looks come first; function second.

| Piece | Tool | Folder |
|---|---|---|
| Embers, clock, weather, now playing (with tinted album art), to-do, codex quote | [Übersicht](https://tracesof.net/uebersicht/) widgets | `ubersicht/` |
| Top bar with your Spaces, a dock of live windows, a ⌘Tab window switcher | **Lace.app**, a small Swift + WKWebView app | `app/` |
| Launcher | [Alfred](https://www.alfredapp.com) 6 theme, translucent | `alfred/` |
| Browser chrome with horizontal tabs, plus a start page for new tabs and home | [Firefox Developer Edition](https://www.mozilla.org/firefox/developer/) `userChrome.css` and an unsigned extension | `firefox/` |
| A full browser mod: three themes, the storm wallpaper, cursors, sidebar and toolbar icons, app icons, splash screen, page shaders, sounds | [Opera GX](https://www.opera.com/gx) mod (schema 2) | `operagx/` |
| Keyboard-browsing hints and omnibar | [Surfingkeys](https://github.com/brookhong/Surfingkeys) theme | `surfingkeys/` |
| The same, for Zen's vertical layout | [Zen](https://zen-browser.app) `userChrome.css` (shares the start page) | `zen/` |
| Terminal | [Ghostty](https://ghostty.org) theme | `ghostty/` |
| Prompt, two lines in gold corner brackets | [starship](https://starship.rs) | `starship.toml` |
| A codex line in each new terminal window | zsh hook | `shell/lace.zsh` |
| Crimson glow on the focused window | [JankyBorders](https://github.com/FelixKratz/JankyBorders) | `borders/` |

**Palette:** ink `#0B0709`, obsidian `#150D10`, crimson `#B3263A`, storm
`#D9474F`, ember `#FF7A3D`, gold `#C9A45C`, bone `#EDE3D1`, ash `#B9B0B8`.

**Type:** Cinzel, Cinzel Decorative, Inter Tight, JetBrains Mono (all free, via Homebrew casks).

## Install

Clone anywhere; the steps below assume `~/lace-ember`.

```bash
R=~/lace-ember
brew install --cask ubersicht font-cinzel font-cinzel-decorative font-inter-tight font-jetbrains-mono
brew install FelixKratz/formulae/borders starship jq

# Übersicht: launch it once, then point its widgets folder here
cd ~/Library/Application\ Support/Übersicht && mv widgets widgets.default && ln -s $R/ubersicht widgets

# Ghostty, starship, borders
ln -sfn $R/ghostty/config ~/.config/ghostty/config
mkdir -p ~/.config/ghostty/themes && ln -sfn $R/ghostty/lace-ember ~/.config/ghostty/themes/lace-ember
ln -sfn $R/starship.toml ~/.config/starship.toml
mkdir -p ~/.config/borders && ln -sfn $R/borders/bordersrc ~/.config/borders/bordersrc
brew services start borders

# the codex line in new Ghostty windows (put it before `eval "$(starship init zsh)"`)
echo "source $R/shell/lace.zsh" >> ~/.zshrc
```

The first time the widgets run, macOS asks whether Übersicht may control Music
and OmniFocus, and OmniFocus asks to allow an external script.

### Lace.app (top bar and dock)

`app/build.sh` compiles `app/main.swift`, bundles `app/web/` and installs to
`~/Applications/Lace.app`. Everything visual is HTML/CSS in `app/web/`;
the Swift only supplies data (Spaces, front app, battery, network, now playing,
windows) and actions.

1. **Optional but recommended:** make a local code-signing certificate so
   macOS keeps Lace's Accessibility permission across rebuilds. With ad-hoc
   signing, every rebuild resets it.
   ```bash
   cd "$(mktemp -d)"
   printf '[req]\ndistinguished_name=dn\nx509_extensions=ext\nprompt=no\n[dn]\nCN=Lace Local Code Signing\n[ext]\nbasicConstraints=critical,CA:false\nkeyUsage=critical,digitalSignature\nextendedKeyUsage=critical,codeSigning\n' > c.cnf
   /usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -keyout k.pem -out c.pem -days 3650 -config c.cnf
   PW=$(/usr/bin/openssl rand -hex 16)
   /usr/bin/openssl pkcs12 -export -inkey k.pem -in c.pem -out l.p12 -passout pass:$PW -name "Lace Local Code Signing"
   security import l.p12 -k ~/Library/Keychains/login.keychain-db -P "$PW" -T /usr/bin/codesign
   rm -f k.pem l.p12
   ```
2. `~/lace-ember/app/build.sh`
3. Start at login: `~/lace-ember/launchd/install.sh`
4. Give Lace **Accessibility** access (System Settings → Privacy & Security).
   It reads windows for the dock, raises them, and runs the ⌘Tab switcher.
5. Turn on **Switch to Desktop 1–N** in System Settings → Keyboard → Keyboard
   Shortcuts → Mission Control. The bar's buttons press ⌃N.
6. Hide the menu bar automatically, and keep the system Dock out of the way.
   It must stay running (it drives Spaces and Mission Control), so make it
   wait before appearing:
   `defaults write com.apple.dock autohide -bool true; defaults write com.apple.dock autohide-delay -float 1000; killall Dock`
   (undo: `defaults delete com.apple.dock autohide-delay; killall Dock`).

**What it does**
- **Bar:** your Desktops as I, II, III…, following every switch; front app,
  now playing, network, battery, clock.
- **Dock:** one tile per open window on the current Space, plus minimised
  windows after a divider. Click raises that window; right-click lists the
  app's windows, Hide and Quit. Apps with no window here don't appear.
- **⌘Tab:** a Lace & Ember block of your windows on every desktop, most
  recent first; ones elsewhere carry their desktop's numeral, and choosing
  one takes you there. Windows are listed down the left with a live preview
  of the chosen one on the right (grant Lace Screen Recording for previews;
  without it you get icon tiles).
  Tab/⇧Tab/←/→ move, Esc cancels, releasing ⌘ switches. It replaces the
  system switcher while Lace runs.

macOS's own window tiling doesn't know about the bar, so tiled windows can
sit under it.

Optional `~/.config/lace/config.json` (any subset of keys):
`dockMode` (`autohide` | `pinned`), `dockContent` (`windows` | `apps`; `apps`
shows a launcher of `dock` bundle IDs, `"|"` for a divider, plus running apps),
`showRunning`, `showMinimised`, `switcher` (`false` keeps the system ⌘Tab),
`switcherAllSpaces` (`false`: this Space's windows only),
`switcherLayout` (`list` | `tiles`),
`stageSource` (`spaces`, or `betterstage` to read
[BetterStage](https://betterstage.app) stages, switched with ⌥N),
`stageKeyMods` (e.g. `["ctrl"]`), `clockApp`.

### Alfred

Open `alfred/Lace & Ember.alfredappearance` to import it, then choose it in
Alfred → Appearance. Built for Alfred 6.

### Firefox

Use **Developer Edition** (or Nightly or ESR): release Firefox only runs
Mozilla-signed extensions, and the start page isn't signed.

```bash
brew install --cask firefox@developer-edition
```

Launch it once so it creates a profile, quit it (⌘Q), then run
`~/lace-ember/firefox/install.sh`. That links `user.js`, `userChrome.css` and
the storm image into the default profile, builds the start page and drops it
into the profile's `extensions/` folder, where `user.js` lets Firefox enable it
at launch. Tabs stay horizontal; the first nine carry Roman numerals (⌘1–9).
Rerun the script after editing the start page or its tiles.

### Websites

Two layers recolour websites to the palette instead of their own dark modes:

- **[Dark Reader](https://darkreader.org)** for every site: import
  `firefox/darkreader-lace-ember.json` (Dark Reader → Settings → Advanced →
  Import Settings).
- **[Stylus](https://github.com/openstyles/stylus)** styles for Reddit,
  YouTube, Google and DuckDuckGo in `firefox/stylus/`. Turn Dark Reader off on
  those sites. To install, serve the folder and open a style's URL so Stylus
  offers to install it (pasting the Less source into "Write new style" won't
  compile):
  ```bash
  cd ~/lace-ember/firefox/stylus && python3 -m http.server 8765 --bind 127.0.0.1
  # then open http://127.0.0.1:8765/youtube.user.css (or reddit, google, duckduckgo)
  ```
  Set YouTube to its Dark appearance. Each style offers a Crimson, Gold or
  Ember accent under Stylus's ⚙.

`firefox/stylus/build.py <site> --fetch` builds a style for any site
[Catppuccin's userstyles](https://github.com/catppuccin/userstyles) cover
(MIT; their colour rules, our palette). Site-specific fixes go in
`firefox/stylus/touches/<site>.css`.

### Opera GX

```bash
brew install node ffmpeg imagemagick librsvg
python3 -m pip install pillow
~/lace-ember/operagx/build.sh
```

Then open `opera://extensions`, switch on Developer mode, **Load unpacked** and
choose `~/lace-ember/operagx/dist/Lace-Ember-GX`. Pick the parts in GX Control →
Mods (themes, wallpaper, cursors, icons, splash screen, fonts, shaders,
speed-dial effects, music, sounds). The app icon needs
`opera://configure/mods/interface/app_icon` and a restart.

For the live wallpaper, point `LACE_STORM_VIDEO` at a looping MP4 before
building; without one the mod uses the still storm. The mod uses GX's newer
schema 2, which Opera doesn't document: each payload key is a list of named
options with unique ids, and the sidebar and toolbar icons (`icons.py`) are
Lottie JSON keyed `sidebar_*_button` / `top_bar_*_button`.

### Surfingkeys

Paste `surfingkeys/theme.js` at the end of your Surfingkeys settings (Advanced
mode) and Save. It styles hints, visual mode, the omnibar, banner, status bar,
help screen and tab overlay.

### Zen

```bash
P="$HOME/Library/Application Support/zen/Profiles/<id>.Default (release)"; R=~/lace-ember/zen
ln -sfn $R/user.js "$P/user.js"
ln -sfn $R/chrome/userChrome.css "$P/chrome/userChrome.css"
ln -sfn $R/storm-clean.jpg "$P/chrome/storm-clean.jpg"
```

Quit Zen fully (⌘Q) and reopen. Then run `zen/build.sh`, and in Zen go to
Add-ons → gear → *Install Add-on From File* → `zen/dist/lace-ember-start.xpi`.
That works because Zen is built without forced extension signing; `user.js`
turns signing off. Stock Firefox would refuse the unsigned extension. Edit the
start page's tiles in `zen/extension/sites.js`.

## The codex

The desktop card, the Zen start page and the terminal greeting all show one
sentence from a folder of Markdown files, quoted word for word and attributed
to its file. The default folder is `~/Craft/Abednego/Lore` (the author's
campaign world). Point `LACE_CODEX_DIR` at your own folder, or edit `LORE` in
`ubersicht/lib/codex.py`. No lore ships with this repo. Without a folder, the
quote simply stays hidden.

## Notes

- Built and tested on macOS with Firefox Developer Edition 161 and Zen 1.24.
  Both rename UI parts now and then, so a `userChrome.css` rule that stops
  matching after an update is the first suspect.
- Übersicht compiles every save. Make a widget change in one write, or a
  half-finished edit shows an error screen over the desktop.
- Check cut-outs and colours against a saturated red, not black, which hides
  grey spill.

## Licence

Code is MIT (see `LICENSE`). **The artwork is not covered:**
`zen/storm-clean.jpg`, `zen/extension/img/storm-clean.jpg` and
`zen/extension/img/naamah-prowl.webp` are © the author, all rights reserved.
They're included so the start page works; please don't reuse them elsewhere.
Fonts are under their own (OFL) licences and aren't bundled.
