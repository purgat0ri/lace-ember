#!/bin/zsh
# Link Lace & Ember into a Firefox (or Floorp) profile and drop in the
# start-page extension.
#
#   install.sh [--floorp] [profile-dir]
#
# Without a profile dir it uses the profile the browser itself marked as
# default in profiles.ini (launch it once first so it makes one). Quit the
# browser first (⌘Q); it reads user.js and new extensions only at launch.
# Rerun after changing the start page.
#
# The start page is unsigned: Developer Edition, Nightly and ESR accept it
# (user.js turns signing off); release Firefox will refuse it.
#
# --floorp also switches Floorp's design from Lepton (a full theme of its own
# that fights this one) to plain Proton; chrome/floorp.css themes the parts
# Floorp adds (panel sidebar, workspaces, status bar).
set -e
here=${0:A:h}
browser=Firefox; proc="Firefox.*\.app/Contents/MacOS/firefox"
if [[ $1 == --floorp ]]; then
  browser=Floorp; proc="Floorp\.app/Contents/MacOS/floorp"; shift
fi
ffdir="$HOME/Library/Application Support/$browser"

if [[ -n $1 ]]; then
  P=${1:A}
else
  # the [Install…] section's Default= is the profile this Firefox opens
  rel=$(awk -F= '/^\[Install/{i=1;next} /^\[/{i=0} i && /^Default=/{print $2; exit}' "$ffdir/profiles.ini")
  [[ -n $rel ]] || { echo "no default profile in $ffdir/profiles.ini; launch $browser once, or pass a profile dir"; exit 1; }
  P="$ffdir/$rel"
fi
[[ -d $P ]] || { echo "no profile at $P"; exit 1; }
if pgrep -f "$proc" >/dev/null; then
  echo "$browser is running; quit it (⌘Q) and rerun"; exit 1
fi

mkdir -p "$P/chrome" "$P/extensions"
# Floorp ships a commented-out userChrome.css stub; keep it once before linking over it
if [[ -f $P/chrome/userChrome.css && ! -L $P/chrome/userChrome.css && ! -e $P/chrome/userChrome.css.orig ]]; then
  mv "$P/chrome/userChrome.css" "$P/chrome/userChrome.css.orig"
fi
ln -sfn $here/user.js "$P/user.js"
ln -sfn $here/chrome/userChrome.css "$P/chrome/userChrome.css"
ln -sfn $here/../zen/storm-clean.jpg "$P/chrome/storm-clean.jpg"
# the icon set: built here, imported by userChrome.css
/usr/bin/python3 $here/icons.py
ln -sfn $here/chrome/icons.css "$P/chrome/icons.css"
# Floorp's own parts; imported by userChrome.css, harmless in Firefox
ln -sfn $here/chrome/floorp.css "$P/chrome/floorp.css"

if [[ $browser == Floorp && -f $P/prefs.js ]]; then
  # floorp.design.configs is one JSON blob, so user.js can't set a key inside
  # it: edit prefs.js (the browser is quit, so it won't be overwritten)
  /usr/bin/python3 - "$P/prefs.js" <<'PY'
import json, re, sys
p = sys.argv[1]; s = open(p).read()
m = re.search(r'user_pref\("floorp\.design\.configs", (".*?(?<!\\)")\);', s)
if m:
    cfg = json.loads(json.loads(m.group(1)))
    if cfg.get("globalConfigs", {}).get("userInterface") != "proton":
        cfg.setdefault("globalConfigs", {})["userInterface"] = "proton"
        new = json.dumps(json.dumps(cfg, separators=(",", ":")))
        s = s[:m.start(1)] + new + s[m.end(1):]
        open(p, "w").write(s)
        print("Floorp design: Lepton -> Proton")
PY
fi

# the start page is shared with Zen: build it there, install it here
$here/../zen/build.sh
cp $here/../zen/dist/lace-ember-start.xpi "$P/extensions/lace-ember-start@local.xpi"
echo "installed into $P"
