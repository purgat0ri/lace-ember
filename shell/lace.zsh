# Lace & Ember — sourced from ~/.zshrc.
# A codex line greets each new Ghostty window or tab: the first interactive
# shell only, never scripts, subshells or other terminals.
if [[ -o interactive && $TERM_PROGRAM == ghostty && -z $LACE_GREETED ]]; then
  export LACE_GREETED=1
  # codex.py relative to this file, wherever the repo is cloned
  /usr/bin/python3 -I ${${(%):-%x}:A:h:h}/ubersicht/lib/codex.py --greet 2>/dev/null
fi
