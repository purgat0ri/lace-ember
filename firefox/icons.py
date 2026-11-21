#!/usr/bin/python3
"""Lace & Ember icons for Firefox: writes chrome/icons.css.

The drawings are the heraldic set from ../vivaldi/icons.py (solid spearheads,
pennons and diamonds in gold), plus the few below that only Firefox needs.
Firefox's toolbar buttons have fixed ids, so each id is simply given a new
image: gold at rest, bone under the pointer, ember while pressed.

userChrome.css imports the built file. To add or change one: edit BUTTONS (or
ICONS in the Vivaldi file), run this file (install.sh does too), restart
Firefox. A button that is not listed keeps Firefox's own icon.
"""
import importlib.util
import os

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("vicons", os.path.join(HERE, "..", "vivaldi", "icons.py"))
vicons = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vicons)

PIECES = {name: pieces for name, (_, pieces) in vicons.ICONS.items()}
PIECES.update({
    # three bars, the middle one broken by a diamond
    "menu": [("s", "M4 6.5h16 M4 17.5h16 M4 12h4.5 M15.5 12H20"), ("f", "M9 12l3-3 3 3-3 3z")],
    # a solid lozenge quartered by a cross
    "extensions": [("f", "M12 2.8l4.1 4.1-4.1 4.1-4.1-4.1z M17.1 7.9l4.1 4.1-4.1 4.1L13 12z "
                         "M6.9 7.9L11 12l-4.1 4.1L2.8 12z M12 13l4.1 4.1-4.1 4.1-4.1-4.1z")],
})

# Firefox button id: drawing
BUTTONS = {
    "sidebar-button": "panel",
    "back-button": "back",
    "forward-button": "forward",
    "reload-button": "reload",
    "stop-button": "stop",
    "home-button": "home",
    "downloads-button": "downloads",
    "developer-button": "page-actions",
    "unified-extensions-button": "extensions",
    "PanelUI-menu-button": "menu",
    "new-tab-button": "new-tab",
    "tabs-newtab-button": "new-tab",
    "alltabs-button": "tab-list",
    "firefox-view-button": "workspaces",
    "bookmarks-menu-button": "bookmarks",
    "library-button": "reading-list",
    "history-panelmenu": "history",
    "preferences-button": "settings",
    "screenshot-button": "capture",
    "sync-button": "sync",
}

GOLD, BONE, EMBER = "c9a45c", "ede3d1", "ff7a3d"


def svg(pieces, colour):
    c = "%23" + colour
    out = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="%s" '
           'stroke-width="1.7" stroke-linecap="square" stroke-linejoin="miter">' % c)
    for kind, d in pieces:
        if kind == "f":
            out += '<path fill="%s" fill-rule="evenodd" stroke="none" d="%s"/>' % (c, d)
        else:
            out += '<path d="%s"/>' % d
    return out + "</svg>"


def rule(bid, state, pieces, colour):
    # the image is set on the button and on its icon: Firefox styles either,
    # depending on the button. The downloads button keeps its icon one level in.
    targets = ["#%s%s" % (bid, state),
               "#%s%s .toolbarbutton-icon" % (bid, state)]
    if bid == "downloads-button":
        targets.append("#%s%s #downloads-indicator-icon" % (bid, state))
    return "%s {\n  list-style-image: url('data:image/svg+xml;utf8,%s') !important;\n}" % (
        ",\n".join(targets), svg(pieces, colour))


def main():
    out = ["/* Built by icons.py. Do not edit: change BUTTONS there and rerun it. */", ""]
    for bid, name in BUTTONS.items():
        pieces = PIECES[name]
        out.append("/* %s: %s */" % (bid, name))
        out.append(rule(bid, "", pieces, GOLD))
        out.append(rule(bid, ":not([disabled]):hover", pieces, BONE))
        out.append(rule(bid, ":not([disabled]):hover:active", pieces, EMBER))
    ids = ",\n".join(":is(#%s) .toolbarbutton-icon" % ", #".join(BUTTONS))
    out.append("")
    out.append("/* drawn at 24px (Firefox's own are 16px), in the same button box; no\n"
               " * recolouring, the colour is in the drawing */")
    out.append("%s {\n  padding: calc(var(--toolbarbutton-inner-padding) - 4px) !important;\n"
               "  width: calc(2 * var(--toolbarbutton-inner-padding) + 16px) !important;\n"
               "  height: calc(2 * var(--toolbarbutton-inner-padding) + 16px) !important;\n"
               "  -moz-context-properties: none !important;\n}" % ids)
    out.append("")
    with open(os.path.join(HERE, "chrome", "icons.css"), "w") as f:
        f.write("\n".join(out))
    print("built chrome/icons.css (%d buttons)" % len(BUTTONS))


if __name__ == "__main__":
    main()
