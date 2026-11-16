#!/bin/zsh
# Link Lace & Ember into a Firefox profile and drop in the start-page extension.
#
#   install.sh [profile-dir]
#
# Without an argument it uses the profile Firefox itself marked as default in
# profiles.ini (launch Firefox once first so it makes one). Quit Firefox first (⌘Q); it reads user.js and new
# extensions only at launch. Rerun after changing the start page.
#
# The start page is unsigned: Developer Edition, Nightly and ESR accept it
# (user.js turns signing off); release Firefox will refuse it.
set -e
here=${0:A:h}
ffdir="$HOME/Library/Application Support/Firefox"

if [[ -n $1 ]]; then
  P=${1:A}
else
  # the [Install…] section's Default= is the profile this Firefox opens
  rel=$(awk -F= '/^\[Install/{i=1;next} /^\[/{i=0} i && /^Default=/{print $2; exit}' "$ffdir/profiles.ini")
  [[ -n $rel ]] || { echo "no default profile in $ffdir/profiles.ini; launch Firefox once, or pass a profile dir"; exit 1; }
  P="$ffdir/$rel"
fi
[[ -d $P ]] || { echo "no profile at $P"; exit 1; }
if pgrep -f "Firefox.*\.app/Contents/MacOS/firefox" >/dev/null; then
  echo "Firefox is running; quit it (⌘Q) and rerun"; exit 1
fi

mkdir -p "$P/chrome" "$P/extensions"
ln -sfn $here/user.js "$P/user.js"
ln -sfn $here/chrome/userChrome.css "$P/chrome/userChrome.css"
ln -sfn $here/../zen/storm-clean.jpg "$P/chrome/storm-clean.jpg"

# the start page is shared with Zen: build it there, install it here
$here/../zen/build.sh
cp $here/../zen/dist/lace-ember-start.xpi "$P/extensions/lace-ember-start@local.xpi"
echo "installed into $P"
