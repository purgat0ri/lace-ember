#!/bin/zsh
# Data for column.jsx, as one JSON object. Runs every few seconds, so the slow
# sources are cached: weather 30 min, OmniFocus 2 min. Now playing is live.
# Never launches Music, Spotify or OmniFocus; it only reads them if running.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"   # jq; Übersicht's PATH is bare
here=${0:A:h}
cache=$HOME/.cache/lace-ember
mkdir -p $cache

fresh() { [[ -s $1 ]] && (( $(date +%s) - $(stat -f %m $1) < $2 )) }

# wttr.in locates by IP; no location is configured or sent.
if ! fresh $cache/weather.json 1800; then
  curl -s -m 8 'https://wttr.in/?format=j1' -o $cache/weather.tmp \
    && jq -e .current_condition $cache/weather.tmp >/dev/null 2>&1 \
    && jq -c '{temp: .current_condition[0].temp_C, code: .current_condition[0].weatherCode,
               desc: .current_condition[0].weatherDesc[0].value,
               hi: .weather[0].maxtempC, lo: .weather[0].mintempC}' $cache/weather.tmp > $cache/weather.json
  rm -f $cache/weather.tmp
fi

if ! fresh $cache/omnifocus.json 120; then
  osascript -l JavaScript $here/omnifocus.js > $cache/omnifocus.tmp 2>/dev/null \
    && jq -e . $cache/omnifocus.tmp >/dev/null 2>&1 && mv $cache/omnifocus.tmp $cache/omnifocus.json
  rm -f $cache/omnifocus.tmp
fi

if ! fresh $cache/codex.json 60; then
  /usr/bin/python3 -I $here/codex.py > $cache/codex.tmp 2>/dev/null && mv $cache/codex.tmp $cache/codex.json
  rm -f $cache/codex.tmp
fi

np=$(osascript -l JavaScript $here/nowplaying.js 2>/dev/null)
[[ -z $np ]] && np='null'
print -r -- $np > $cache/np.json   # the Lace bar reads this

# Album art (Apple Music only): exported once per track into ../art, which
# Übersicht serves, so the widget can load it as art/<key>.<ext>. Only the
# current cover is kept. A track without artwork leaves a .none marker.
art=null
if [[ $np != null && $(jq -r .app <<<$np) == Music ]]; then
  artdir=${here:h}/art
  key=$(jq -r '[.title,.artist,.album]|join("|")' <<<$np | shasum | cut -c1-12)
  have=($artdir/$key.*(N))
  if (( ${#have} == 0 )); then
    mkdir -p $artdir && rm -f $artdir/*(N)
    if osascript $here/artwork.applescript $artdir/$key.tmp 2>/dev/null && [[ -s $artdir/$key.tmp ]]; then
      case $(file -b --mime-type $artdir/$key.tmp) in
        image/png) mv $artdir/$key.tmp $artdir/$key.png ;;
        image/jpeg) mv $artdir/$key.tmp $artdir/$key.jpg ;;
        *) rm -f $artdir/$key.tmp; touch $artdir/$key.none ;;
      esac
    else
      rm -f $artdir/$key.tmp; touch $artdir/$key.none
    fi
  fi
  f=$(ls $artdir/$key.png $artdir/$key.jpg 2>/dev/null | head -1)
  [[ -n $f ]] && art="\"art/${f:t}\""
fi

print -r -- "{\"weather\":$(cat $cache/weather.json 2>/dev/null || echo null),\"tasks\":$(cat $cache/omnifocus.json 2>/dev/null || echo null),\"np\":$np,\"art\":$art,\"codex\":$(cat $cache/codex.json 2>/dev/null || echo null)}"
