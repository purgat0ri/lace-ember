#!/usr/bin/python3
"""Lace & Ember icons for Vivaldi: writes icons.css beside this file.

The set is heraldic rather than thin-line, so it reads as Lace & Ember and not
as Vivaldi's stock icons: solid spearheads, pennons and diamonds, cut square
and mitred like the gold corner pins, resting in gold (bone on hover, ember
while pressed). Each icon is a 24x24 drawing built from two kinds of piece:
("f", path) is filled solid, ("s", path) is a 1.7 line.

Vivaldi's toolbar buttons carry no stable class, only a tooltip, so each icon
is matched on the start of the button's English title (or its aria-label:
a disabled button has no title). The drawing is applied
as a CSS mask over the button's colour.

To add or change one: edit ICONS, run this file (install.sh does too), restart
Vivaldi. A button whose title matches nothing keeps Vivaldi's own icon.
"""
import os

D = "M%s %sl2.2-2.2 2.2 2.2-2.2 2.2z"          # a small diamond whose left point is at x, y

# name: (title prefixes, pieces)
ICONS = {
    # ---- tab bar
    # three stacked lozenges, the top one solid
    "workspaces": (["Workspaces"], [("f", "M12 3.5l7.5 3.8-7.5 3.8-7.5-3.8z"),
                                    ("s", "M4.5 11.6l7.5 3.8 7.5-3.8 M4.5 15.9l7.5 3.8 7.5-3.8")]),
    # a four-pointed spark
    "new-tab": (["Open a New Tab"], [("f", "M12 2.5l2.1 7.4 7.4 2.1-7.4 2.1-2.1 7.4-2.1-7.4-7.4-2.1 7.4-2.1z")]),
    # a hanging point under a bar
    "tab-list": (["Tabs ("], [("s", "M5 7h14"), ("f", "M6 10.5h12l-6 7.5z")]),

    # ---- navigation
    # a frame with the panel side solid
    "panel": (["Hide Panel", "Show Panel"], [("s", "M4 5h16v14H4z"), ("f", "M4 5h5.5v14H4z")]),
    # spearheads with a diamond at the butt
    "back": (["Previous Page"], [("f", "M3 12l8-6.5v13z"), ("s", "M11 12h5.5"), ("f", D % (16.6, 12))]),
    "forward": (["Next Page"], [("f", "M21 12l-8-6.5v13z"), ("s", "M13 12H7.5"), ("f", D % (3, 12))]),
    # an open ring closing on a solid point, a diamond at its heart
    "reload": (["Reload"], [("s", "M18.6 12.4a6.6 6.6 0 1 1-2.5-5.5"), ("f", "M19.8 2.8v6.4h-6.4z"),
                            ("f", D % (9.8, 12))]),
    # a saltire with a diamond boss
    "stop": (["Stop"], [("s", "M6 6l12 12 M18 6L6 18"), ("f", "M8.6 12l3.4-3.4 3.4 3.4-3.4 3.4z")]),
    # a gabled house with a dark door
    "home": (["Go to homepage", "Home"], [("f", "M12 3.5l8.5 7.5H18v8.5h-4.2V14h-3.6v5.5H6V11H3.5z")]),

    # ---- side panel
    # a pennon with a swallow tail
    "bookmarks": (["Bookmarks"], [("f", "M6.5 3.5h11v17l-5.5-4.6-5.5 4.6z")]),
    # a spearhead driven down onto a base line
    "downloads": (["Downloads"], [("s", "M12 3.5v6"), ("f", "M5.5 9.5h13l-6.5 7.5z"), ("s", "M4.5 20h15")]),
    # an hourglass, the sand run through
    "history": (["History"], [("s", "M6 3.8h12 M6 20.2h12 M7.2 3.8v2.4l4.8 5.8 4.8-5.8V3.8 M7.2 20.2v-2.4l4.8-5.8"),
                              ("f", "M12 12l4.8 5.8v2.4H7.2v-2.4z")]),
    # a leaf with its corner turned and ruled lines
    "notes": (["Notes"], [("s", "M6 3.8h8.5l3.5 3.5v13H6z M9 12h6 M9 15.6h6"), ("f", "M14 3.8l4 4h-4z")]),
    "translate": (["Translate"], [("s", "M3.8 6.5h8.4 M8 4.2v2.3 M5.3 6.5c.5 3 2.6 5.6 6.2 7 M10.7 6.5c-.5 3-2.6 5.6-6.2 7"),
                                  ("f", "M16.5 9.5l4.3 11h-2.1l-.9-2.5h-2.6l-.9 2.5h-2.1z M16.5 13.6l-.8 2.6h1.6z")]),
    # two panes, the front one solid
    "windows": (["Windows and Tabs"], [("f", "M3.8 8.5h12v11h-12z"), ("s", "M8.5 5.5V4.5h11.7v11.3h-1.5")]),
    # an open book, the read page solid
    "reading-list": (["Reading List"], [("f", "M12 6.2C9.8 4.8 7 4.6 3.8 5.3v13c3.2-.7 6-.5 8.2.9z"),
                                        ("s", "M12 6.2c2.2-1.4 5-1.6 8.2-.9v13c-3.2-.7-6-.5-8.2.9")]),
    # a lozenge frame around a cross
    "add-panel": (["Customize Panel", "Add Web Panel"], [("s", "M12 3.2l8.8 8.8-8.8 8.8-8.8-8.8z M12 8.6v6.8 M8.6 12h6.8")]),

    # ---- status bar
    # a solid eight-sided nut with a round bore
    "settings": (["Settings"], [("f", "M8.5 3.5h7l5 5v7l-5 5h-7l-5-5v-7z M12 8.6a3.4 3.4 0 1 0 0 6.8 3.4 3.4 0 0 0 0-6.8z")]),
    # two columns, a Roman II
    "break": (["Take a Break"], [("f", "M6.5 4h4.2v1.8h-1v12.4h1V20H6.5v-1.8h1V5.8h-1z M13.3 4h4.2v1.8h-1v12.4h1V20h-4.2v-1.8h1V5.8h-1z")]),
    # a solid cloud
    "sync": (["Sync"], [("f", "M7.3 19a4.3 4.3 0 0 1-.7-8.5 5.8 5.8 0 0 1 11.2 1.2 3.7 3.7 0 0 1-.5 7.3z")]),
    # the four corner pins, with a diamond between them
    "auto-hide": (["Toggle UI Auto-hide"], [("s", "M4 9.5V4h5.5 M14.5 4H20v5.5 M20 14.5V20h-5.5 M9.5 20H4v-5.5"),
                                            ("f", "M8.8 12l3.2-3.2 3.2 3.2-3.2 3.2z")]),
    # corner pins around a solid eye
    "capture": (["Capture Page"], [("s", "M4 9V4.5h4.5 M15.5 4.5H20V9 M20 15v4.5h-4.5 M8.5 19.5H4V15"),
                                   ("f", "M12 8.4a3.6 3.6 0 1 0 0 7.2 3.6 3.6 0 0 0 0-7.2z")]),
    # a frame with one half solid
    "tiling": (["Page tiling"], [("s", "M4 5h16v14H4z"), ("f", "M12 5h8v14h-8z")]),
    # chevrons either side of a diamond
    "page-actions": (["Page Actions"], [("s", "M8 6.5L3.5 12 8 17.5 M16 6.5l4.5 5.5-4.5 5.5"),
                                        ("f", "M9 12l3-4 3 4-3 4z")]),
}

OPEN = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="black" '
        'stroke-width="1.7" stroke-linecap="square" stroke-linejoin="miter">')
FILL = '<path fill="black" fill-rule="evenodd" stroke="none" d="%s"/>'
LINE = '<path d="%s"/>'
SCOPE = "#browser .button-toolbar > button"


def svg(pieces):
    return OPEN + "".join((FILL if kind == "f" else LINE) % d for kind, d in pieces) + "</svg>"


def sel(prefixes, tail=""):
    # a disabled button drops its title and keeps only an aria-label
    return ",\n".join('%s[%s^="%s"]%s' % (SCOPE, attr, p, tail)
                       for p in prefixes for attr in ("title", "aria-label"))


def main():
    out = ["/* Built by icons.py. Do not edit: change ICONS there and rerun it. */", ""]
    everything = [p for prefixes, _ in ICONS.values() for p in prefixes]
    for name, (prefixes, pieces) in ICONS.items():
        out.append("/* %s */" % name)
        out.append("%s {\n  --le-icon: url('data:image/svg+xml;utf8,%s');\n}" % (sel(prefixes), svg(pieces)))
    out.append("")
    out.append("/* gold at rest, bone under the pointer, ember while pressed */")
    out.append("%s {\n  color: #c9a45c !important;\n}" % sel(everything))
    out.append("%s {\n  color: #ede3d1 !important;\n}" % sel(everything, ":not([disabled]):hover"))
    out.append("%s {\n  color: #ff7a3d !important;\n}" % sel(everything, ":not([disabled]):active"))
    out.append("%s {\n  color: rgba(201, 164, 92, 0.35) !important;\n}" % sel(everything, "[disabled]"))
    out.append("%s {\n  background-color: currentColor !important;\n"
               "  -webkit-mask: var(--le-icon) center / 20px 20px no-repeat;\n"
               "  mask: var(--le-icon) center / 20px 20px no-repeat;\n}" % sel(everything, " .button-icon"))
    out.append("%s {\n  opacity: 0 !important;\n}" % sel(everything, " .button-icon > svg"))
    out.append("")
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, "icons.css"), "w") as f:
        f.write("\n".join(out))
    print("built icons.css (%d icons)" % len(ICONS))


if __name__ == "__main__":
    main()
