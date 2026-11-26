#!/usr/bin/env python3
"""Lace & Ember interface icons for the Opera GX mod's image_overrides ("Icons").

GX swaps its sidebar (19 px) and toolbar (17 px) buttons for Lottie JSON, one file per
key (keys as in GX's own Cyberpunk mod). Each icon here is drawn once on a 24-unit grid
as bone line-art with one ember accent, then written two ways: Lottie for GX, and SVG for
the preview sheet. The ember accent flickers over the 1 s animation.

usage: icons.py OUT_DIR   writes OUT_DIR/icons/*.json and icons/preview.png,
                          prints the image_overrides entry's "images" map as JSON
"""
import json, math, os, re, subprocess, sys, tempfile

BONE = (0.929, 0.890, 0.820)     # #EDE3D1
EMBER = (1.0, 0.478, 0.239)      # #FF7A3D
CRIMSON = (0.839, 0.271, 0.306)  # #D6454E
GOLD = (0.788, 0.643, 0.361)     # #C9A45C
K = 0.5523  # cubic handle length for a quarter circle


def arc(cx, cy, r, a0, a1, move=True):
    """SVG path text for a circular arc from angle a0 to a1 (degrees, 0 = east, clockwise on screen)."""
    n = max(1, math.ceil(abs(a1 - a0) / 90))
    step = (a1 - a0) / n
    pt = lambda a: (cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)))
    x, y = pt(a0)
    out = [f"M{x:.3f},{y:.3f}"] if move else [f"L{x:.3f},{y:.3f}"]
    for k in range(n):
        s, e = a0 + k * step, a0 + (k + 1) * step
        h = 4 / 3 * math.tan(math.radians(e - s) / 4) * r
        (x0, y0), (x1, y1) = pt(s), pt(e)
        c1 = (x0 - h * math.sin(math.radians(s)), y0 + h * math.cos(math.radians(s)))
        c2 = (x1 + h * math.sin(math.radians(e)), y1 - h * math.cos(math.radians(e)))
        out.append(f"C{c1[0]:.3f},{c1[1]:.3f} {c2[0]:.3f},{c2[1]:.3f} {x1:.3f},{y1:.3f}")
    return " ".join(out)


def arc_arrow(cx, cy, r, a0, a1, head=3.2):
    """An open circular arc a0 -> a1 (clockwise if a1 > a0) with an arrowhead at its a1 end, pointing onward."""
    t = math.radians(a1)
    tip = (cx + r * math.cos(t), cy + r * math.sin(t))
    sg = 1 if a1 > a0 else -1
    back = (sg * math.sin(t), -sg * math.cos(t))  # unit vector pointing back along the arc
    arm = lambda deg: (tip[0] + head * (back[0] * math.cos(math.radians(deg)) - back[1] * math.sin(math.radians(deg))),
                       tip[1] + head * (back[0] * math.sin(math.radians(deg)) + back[1] * math.cos(math.radians(deg))))
    (x1, y1), (x2, y2) = arm(40), arm(-40)
    return arc(cx, cy, r, a0, a1) + f" M{x1:.3f},{y1:.3f} L{tip[0]:.3f},{tip[1]:.3f} L{x2:.3f},{y2:.3f}"


def circle(cx, cy, r):
    return arc(cx, cy, r, 0, 360) + " Z"


def diamond(cx, cy, rx, ry=None):
    ry = ry or rx * 1.35
    return f"M{cx},{cy-ry} L{cx+rx},{cy} L{cx},{cy+ry} L{cx-rx},{cy} Z"


def parse(d):
    """SVG path text (M L H V C Q Z, absolute or relative) -> list of (points, closed);
    points are (vertex, in_handle_abs, out_handle_abs)."""
    toks = re.findall(r"[MLHVCQZmlhvcqz]|-?\d*\.?\d+(?:e-?\d+)?", d)
    subs, cur, pos, start, i, cmd = [], None, (0.0, 0.0), (0.0, 0.0), 0, None
    num = lambda: float(toks[i])
    def add(v, cin=None):
        cur.append([v, cin or v, v])
    while i < len(toks):
        t = toks[i]
        if re.match(r"[A-Za-z]", t):
            cmd = t; i += 1
            if cmd in "Zz":
                if cur:
                    if len(cur) > 1 and math.dist(cur[-1][0], cur[0][0]) < 1e-3:
                        cur[0][1] = cur[-1][1]; cur.pop()
                    subs.append((cur, True)); cur = None; pos = start
                continue
        rel = cmd.islower(); C = cmd.upper()
        ox, oy = pos if rel else (0.0, 0.0)
        if C == "M":
            if cur: subs.append((cur, False))
            pos = (num() + ox, float(toks[i + 1]) + oy); i += 2
            cur = []; add(pos); start = pos
            cmd = "l" if rel else "L"
        elif C == "L":
            pos = (num() + ox, float(toks[i + 1]) + oy); i += 2; add(pos)
        elif C == "H":
            pos = (num() + ox, pos[1]); i += 1; add(pos)
        elif C == "V":
            pos = (pos[0], num() + (pos[1] if rel else 0)); i += 1; add(pos)
        elif C == "C":
            v = [float(toks[i + k]) for k in range(6)]; i += 6
            c1, c2, p = (v[0] + ox, v[1] + oy), (v[2] + ox, v[3] + oy), (v[4] + ox, v[5] + oy)
            cur[-1][2] = c1; add(p, c2); pos = p
        elif C == "Q":
            v = [float(toks[i + k]) for k in range(4)]; i += 4
            q, p = (v[0] + ox, v[1] + oy), (v[2] + ox, v[3] + oy)
            p0 = pos
            c1 = (p0[0] + 2 / 3 * (q[0] - p0[0]), p0[1] + 2 / 3 * (q[1] - p0[1]))
            c2 = (p[0] + 2 / 3 * (q[0] - p[0]), p[1] + 2 / 3 * (q[1] - p[1]))
            cur[-1][2] = c1; add(p, c2); pos = p
    if cur: subs.append((cur, False))
    return subs


# Each icon: list of layers (d, kind, colour, flicker). kind: "s" stroke, "f" fill.
S = lambda d, c=BONE: (d, "s", c, False)
F = lambda d, c=BONE: (d, "f", c, False)
E = lambda d, c=EMBER: (d, "f", c, True)          # the flickering ember accent

def lancet(x0, x1, ybase, ytop):
    """A gothic pointed arch: walls from (x0,ybase) and (x1,ybase) rising to an apex at ytop."""
    m, w = (x0 + x1) / 2, x1 - x0
    spring = ytop + w * 0.6
    return (f"M{x0},{ybase} L{x0},{spring} C{x0},{ytop + w*0.25} {m - w*0.12},{ytop + w*0.08} {m},{ytop} "
            f"C{m + w*0.12},{ytop + w*0.08} {x1},{ytop + w*0.25} {x1},{spring} L{x1},{ybase}")

ICONS = {
    # sidebar, 19 px
    "speeddial": [S(lancet(5, 19, 20.5, 3) + " Z"), S("M12,20.5 L12,11"), S("M5,13.5 L19,13.5"),
                  E(diamond(12, 8.4, 1.5))],
    "bookmarks": [S("M6.5,3.5 L17.5,3.5 L17.5,20.5 L12,16 L6.5,20.5 Z"), E(diamond(12, 9.5, 2))],
    "history": [S(arc_arrow(12, 12, 8.5, 500, 205)), S("M12,7 L12,12 L15.5,14"),
                E(circle(12, 12, 1.15))],
    "downloads": [S("M12,3 L12,13.5 M7.5,9.5 L12,14 L16.5,9.5"), S("M4,15.5 C4,19 6.5,20.5 12,20.5 C17.5,20.5 20,19 20,15.5"),
                  E(diamond(12, 17.6, 1.2, 1.2))],
    "extensions": [S(circle(8, 8, 4.2)), S(circle(8, 8, 1.6)), S("M11,11 L20,20 M16.5,16.5 L18.5,14.5 M18.5,18.5 L20.5,16.5"),
                   E(diamond(8, 8, 0.9, 0.9))],
    "settings": [S(" ".join(
                    f"M{12+8.5*math.cos(math.radians(a)):.3f},{12+8.5*math.sin(math.radians(a)):.3f} "
                    f"L{12+4.6*math.cos(math.radians(a+22.5)):.3f},{12+4.6*math.sin(math.radians(a+22.5)):.3f}"
                    f" L{12+8.5*math.cos(math.radians(a+45)):.3f},{12+8.5*math.sin(math.radians(a+45)):.3f}"
                    for a in range(-90, 270, 45))), S(circle(12, 12, 2.6)), E(circle(12, 12, 1))],
    "mods": [S("M19.5,3.5 C12,4 6.5,9.5 5.5,18.5 C9,17.5 11,16 12.5,14 L9.5,13.5 L13.5,12 C15.5,9.5 17.5,7 19.5,3.5 Z"),
             S("M17,6.5 C13,9 10,12.5 7.5,16.5"), S("M5.5,18.5 L4.5,19.5"), E(diamond(3.6, 20.6, 1.1, 1.4))],
    "shaders": [S("M2.5,12 C5.5,6.5 9,4.5 12,4.5 C15,4.5 18.5,6.5 21.5,12 C18.5,17.5 15,19.5 12,19.5 C9,19.5 5.5,17.5 2.5,12 Z"),
                S(circle(12, 12, 4)), E(diamond(12, 12, 1.4, 2.4))],
    "news": [S("M6.5,4 L17.5,4 C19,4 19.5,5 19.5,6 L19.5,6.5 L17.5,6.5 M17.5,4 C16,4 15.5,5 15.5,6 L15.5,18 "
               "C15.5,19.2 14.8,20 13.5,20 L5,20 C3.8,20 3.5,19.2 3.5,18 L3.5,17.5 L13.5,17.5 L13.5,18 "
               "C13.5,19.2 14.2,20 15,20"), S("M6.5,4 C5.2,4 4.5,5 4.5,6 L4.5,17.5"),
             S("M7.5,8 L12.5,8 M7.5,11 L12.5,11 M7.5,14 L10,14"), E(diamond(12.3, 14, 1, 1.3))],
    "pinboards": [S(diamond(12, 6.5, 3.4, 3.8)), S("M12,10.3 L12,21"), S("M7,13 L17,13"), E(diamond(12, 6.5, 1.1, 1.4))],
    "player": [S("M7.5,4 C4,7 4.5,12 7.5,14.5 L7.5,19.5 L16.5,19.5 L16.5,14.5 C19.5,12 20,7 16.5,4"),
               S("M7.5,14.5 L16.5,14.5"), S("M10,9 L10,17 M12,8 L12,17 M14,9 L14,17"), S("M6,4.5 L9,3.5 M18,4.5 L15,3.5"),
               E(diamond(12, 5.2, 1))],
    "limiters": [S("M6.5,3.5 L17.5,3.5 M6.5,20.5 L17.5,20.5"),
                 S("M7.5,3.5 C7.5,8 11,10 11,12 C11,14 7.5,16 7.5,20.5 M16.5,3.5 C16.5,8 13,10 13,12 C13,14 16.5,16 16.5,20.5"),
                 E("M9.5,20.5 C10,18 11.2,17.4 12,15.5 C12.8,17.4 14,18 14.5,20.5 Z")],
    "crypto_wallet": [S(circle(12, 12, 8.5)), S(circle(12, 12, 6.2)), E(diamond(12, 12, 2.4, 3.4))],
    "easy_share": [S(circle(9, 12, 5)), S(circle(15, 12, 5)), E(diamond(12, 12, 1, 1.4))],
    "gx_booster": [S("M17.5,3 L10.5,12"), S("M10.5,12 L13,14 M8.5,10.5 L13,14 C11,18 8,20.5 3.5,21 C4,16.5 5.5,13 8.5,10.5"),
                   S("M6,18.5 L9.5,15 M5,16 L8,13.5"), E(diamond(19, 7.5, 1.1))],
    # toolbar, 17 px
    "back": [S("M19.5,12 L6,12 M10.5,7 L5.5,12 L10.5,17"), E(diamond(19.5, 12, 1.4, 1.4))],
    "forward": [S("M4.5,12 L18,12 M13.5,7 L18.5,12 L13.5,17"), E(diamond(4.5, 12, 1.4, 1.4))],
    "reload": [S(arc_arrow(12, 12, 7.5, -60, 240)), E(diamond(12, 12, 1.4))],
    "account": [S(circle(12, 8.5, 4)), S("M4.5,21 C4.5,16 8,13.8 12,13.8 C16,13.8 19.5,16 19.5,21"),
                E(diamond(12, 17.6, 1, 1.4))],
    "downloads_top": [S("M12,3.5 L12,15 M7,10 L12,15 L17,10"), S("M4.5,20 L19.5,20"), E(diamond(12, 20, 1.3, 1.3))],
    "easy_setup": [S("M4,6.5 L20,6.5 M4,12 L20,12 M4,17.5 L20,17.5"),
                   F(diamond(8.5, 6.5, 1.9), BONE), E(diamond(15.5, 12, 1.9)), F(diamond(10.5, 17.5, 1.9), BONE)],
    "extensions_top": None,  # same key as the sidebar one, drawn at 17 px
}
ICONS["extensions_top"] = ICONS["extensions"]

# GX key -> (icon, size)
KEYS = {
    "sidebar_speeddial_button": ("speeddial", 19), "sidebar_bookmarks_button": ("bookmarks", 19),
    "sidebar_history_button": ("history", 19), "sidebar_downloads_button": ("downloads", 19),
    "sidebar_extensions_button": ("extensions", 19), "sidebar_settings_button": ("settings", 19),
    "sidebar_mods_button": ("mods", 19), "sidebar_shaders_button": ("shaders", 19),
    "sidebar_news_button": ("news", 19), "sidebar_pinboards_button": ("pinboards", 19),
    "sidebar_player_service_button": ("player", 19), "sidebar_limiters_button": ("limiters", 19),
    "sidebar_crypto_wallet_button": ("crypto_wallet", 19), "sidebar_easy_share_button": ("easy_share", 19),
    "sidebar_gx_booster_button": ("gx_booster", 19),
    "top_bar_back_button": ("back", 17), "top_bar_forward_button": ("forward", 17),
    "top_bar_reload_button": ("reload", 17), "top_bar_account_button": ("account", 17),
    "top_bar_downloads_button": ("downloads_top", 17), "top_bar_easy_setup_button": ("easy_setup", 17),
    "top_bar_extensions_button": ("extensions_top", 17),
}

st = lambda v: {"a": 0, "k": v}
TR = {"ty": "tr", "a": st([0, 0]), "p": st([0, 0]), "s": st([100, 100]), "r": st(0), "o": st(100), "sk": st(0), "sa": st(0)}
FLICKER = {"a": 1, "k": [
    {"t": 0, "s": [100], "o": {"x": [0.45], "y": [0]}, "i": {"x": [0.55], "y": [1]}},
    {"t": 18, "s": [55], "o": {"x": [0.45], "y": [0]}, "i": {"x": [0.55], "y": [1]}},
    {"t": 32, "s": [90], "o": {"x": [0.45], "y": [0]}, "i": {"x": [0.55], "y": [1]}},
    {"t": 44, "s": [45], "o": {"x": [0.45], "y": [0]}, "i": {"x": [0.55], "y": [1]}},
    {"t": 60, "s": [100]}]}


def lottie(layers, size):
    sw = 1.3 * 24 / size  # ~1.3 px on screen, like GX's own icons
    groups = []
    for d, kind, col, flick in layers:
        items = []
        for pts, closed in parse(d):
            v = [p[0] for p in pts]
            i = [(p[1][0] - p[0][0], p[1][1] - p[0][1]) for p in pts]
            o = [(p[2][0] - p[0][0], p[2][1] - p[0][1]) for p in pts]
            r = lambda L: [[round(x, 3), round(y, 3)] for x, y in L]
            items.append({"ty": "sh", "d": 1, "ks": st({"c": closed, "v": r(v), "i": r(i), "o": r(o)})})
        op = FLICKER if flick else st(100)
        if kind == "s":
            items.append({"ty": "st", "lc": 2, "lj": 2, "ml": 4, "o": op, "w": st(round(sw, 3)), "c": st([*col, 1])})
        else:
            items.append({"ty": "fl", "r": 1, "o": op, "c": st([*col, 1])})
        items.append(TR)
        groups.append({"ty": "gr", "it": items})
    groups.reverse()  # Lottie paints the first shape on top
    sc = size / 24 * 100
    return {"v": "5.5.2", "fr": 60, "ip": 0, "op": 60, "w": size, "h": size, "ddd": 0, "assets": [],
            "layers": [{"ddd": 0, "ty": 4, "ind": 0, "sr": 1, "ip": 0, "op": 60, "st": 0, "ao": 0, "bm": 0,
                        "ks": {"a": st([0, 0]), "p": st([0, 0]), "s": st([sc, sc]), "r": st(0), "o": st(100),
                               "sk": st(0), "sa": st(0)}, "shapes": groups}]}


def svg(layers, size):
    sw = 1.3 * 24 / size
    hexc = lambda c: "#%02x%02x%02x" % tuple(round(x * 255) for x in c)
    body = "".join(
        f'<path d="{d}" fill="none" stroke="{hexc(c)}" stroke-width="{sw:.3f}" stroke-linecap="round" stroke-linejoin="round"/>'
        if k == "s" else f'<path d="{d}" fill="{hexc(c)}"/>' for d, k, c, _ in layers)
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">{body}</svg>'


def main():
    out = sys.argv[1]
    os.makedirs(f"{out}/icons", exist_ok=True)
    images, tiles = {}, []
    with tempfile.TemporaryDirectory() as tmp:
        for key, (name, size) in KEYS.items():
            path = f"icons/{key}.json"
            json.dump(lottie(ICONS[name], size), open(f"{out}/{path}", "w"), separators=(",", ":"))
            images[key] = path
            s = f"{tmp}/{key}.svg"; open(s, "w").write(svg(ICONS[name], size))
            for px, tag in ((128, "big"), (size, "real")):
                subprocess.run(["rsvg-convert", "-w", str(px * 2 if tag == "real" else px), "-h",
                                str(px * 2 if tag == "real" else px), s, "-o", f"{tmp}/{key}-{tag}.png"], check=True)
            tiles.append(key)
        # preview: big icons on dusk wine, with the real (2x) size underneath each
        args = []
        for k in tiles:
            args += ["(", f"{tmp}/{k}-big.png", f"{tmp}/{k}-real.png", "-background", "#2A1C25",
                     "-gravity", "center", "-append", "-extent", "150x190", ")"]
        rows = [args[i:i + 8 * 11] for i in range(0, len(args), 8 * 11)]
        for n, r in enumerate(rows):
            subprocess.run(["magick", *r, "-background", "#2A1C25", "+append", "-gravity", "west",
                            "-extent", f"{150*8}x190", f"{tmp}/row{n}.png"], check=True)
        subprocess.run(["magick", *[f"{tmp}/row{n}.png" for n in range(len(rows))], "-append",
                        f"{out}/icons/preview.png"], check=True)
    print(json.dumps(images))


if __name__ == "__main__":
    main()
