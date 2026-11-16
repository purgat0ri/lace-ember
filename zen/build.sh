#!/bin/zsh
# Package extension/ as dist/lace-ember-start.xpi (unsigned; Zen allows it once
# xpinstall.signatures.required is false, which user.js sets).
# Bump "version" in extension/manifest.json before rebuilding, then in Zen:
# Add-ons → gear → Install Add-on From File… → dist/lace-ember-start.xpi
set -e
here=${0:A:h}
# the codex pool, so the page picks the same quote as the desktop without a fetch
/usr/bin/python3 -I $here/../ubersicht/lib/codex.py --pool-js > $here/extension/codex-pool.js
mkdir -p $here/dist
rm -f $here/dist/lace-ember-start.xpi
cd $here/extension
zip -q -r -X $here/dist/lace-ember-start.xpi . -x '.DS_Store' '*/.DS_Store'
echo "built $here/dist/lace-ember-start.xpi ($(du -h $here/dist/lace-ember-start.xpi | cut -f1))"
