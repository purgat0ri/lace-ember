#!/bin/zsh
# Lace & Ember for Vivaldi: CSS only, nothing written into the app bundle.
# Quit Vivaldi first. Safe to rerun (after lore, start-page or storm changes).
#
#   1. builds storm.css (the storm image as a data URI; the mods folder only
#      serves .css), icons.css (from icons.py) and the start page's codex pool
#   2. turns on the "CSS modifications" experiment and points Custom UI
#      Modifications at this folder
#   3. adds the "Lace & Ember" theme, selects it and turns the light/dark theme
#      schedule off (the schedule would override it)
#   4. makes new tabs and the home page open the start page (zen/extension/
#      newtab.html, straight from this repo as a file: URL)
#
# Works before Vivaldi's first launch too: it seeds the two files and Vivaldi
# fills in the rest. Pass a user-data dir to target another profile.
set -e
here=${0:A:h}
data=${1:-$HOME/Library/Application Support/Vivaldi}

if pgrep -f "Vivaldi.app/Contents/MacOS/Vivaldi" >/dev/null && [[ -z $1 ]]; then
  echo "Quit Vivaldi first: it rewrites its settings on exit." >&2; exit 1
fi

{ printf '/* Built by install.sh from ../zen/storm-clean.jpg. Do not edit. */\n#browser { --le-storm-image: url("data:image/jpeg;base64,'
  base64 -i $here/../zen/storm-clean.jpg | tr -d '\n'
  printf '"); }\n'; } > $here/storm.css
/usr/bin/python3 -I $here/icons.py >/dev/null
/usr/bin/python3 -I $here/../ubersicht/lib/codex.py --pool-js > $here/../zen/extension/codex-pool.js

mkdir -p "$data/Default"
/usr/bin/python3 -I - "$data" "$here" <<'PY'
import json, os, sys
data, here = sys.argv[1], sys.argv[2]
start = "file://" + os.path.realpath(os.path.join(here, "..", "zen", "extension", "newtab.html"))

def load(p):
    try:
        with open(p) as f: return json.load(f)
    except FileNotFoundError:
        return {}
def save(p, d):
    if os.path.exists(p) and not os.path.exists(p + ".pre-lace"):
        os.replace(p, p + ".pre-lace")          # one backup, from before the first install
    with open(p, "w") as f: json.dump(d, f)

theme = {
    "engineVersion": 1, "version": 1, "id": "LaceEmber1", "name": "Lace & Ember", "url": "",
    "accentFromPage": False, "accentOnWindow": False, "accentSaturationLimit": 1,
    "alpha": 1, "blur": 0, "backgroundImage": "", "backgroundPosition": "stretch", "backgroundSource": "",
    # colorBg is dusk-dark (violet-black), not ink: Vivaldi derives every popup,
    # dropdown, panel and settings page from it, and ink read as flat black
    # against the dusk wash
    "colorAccentBg": "#2a1b24", "colorBg": "#1e1826", "colorFg": "#ede3d1",
    "colorHighlightBg": "#b3263a", "colorPosition": "unified", "colorWindowBg": "#1e1826",
    "contrast": 0, "defaultBackground": "#1e1826", "preferSystemAccent": False, "radius": 0,
    "transparencyTabBar": False, "transparencyTabs": False, "dimBlurred": False, "simpleScrollbar": True,
}

p = os.path.join(data, "Default", "Preferences")
d = load(p); v = d.setdefault("vivaldi", {})
themes = v.setdefault("themes", {})
themes["user"] = [t for t in themes.get("user", []) if t.get("id") != theme["id"]] + [theme]
themes["current"] = theme["id"]
# enums are stored by position: schedule off = 0; new-tab page "custom" = 4
v.setdefault("theme", {}).setdefault("schedule", {})["enabled"] = 0
v.setdefault("appearance", {})["css_ui_mods_directory"] = here
v.setdefault("tabs", {}).setdefault("new_page", {}).update(link=4, custom_url=start)
v["homepage"] = start
save(p, d)

p = os.path.join(data, "Local State")
d = load(p)
# needed by older Vivaldi; 8.3 loads the folder without it and drops the entry
labs = d.setdefault("browser", {}).setdefault("enabled_labs_experiments", [])
if "vivaldi-css-mods" not in labs: labs.append("vivaldi-css-mods")
save(p, d)
print("Lace & Ember set up in", data)
PY
