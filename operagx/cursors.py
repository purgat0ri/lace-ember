#!/usr/bin/env python3
"""Draw the Lace & Ember cursor set and pack it as Windows .cur / .ani files,
which is what Opera GX mods load (the hotspot lives in the file).

Each cursor is an SVG on a 32-unit grid: bone body, ink outline, a crimson
facet, gold diamond accents. rsvg-convert renders it at 32 and 64 px; both
go into one .cur (32-bit BGRA bitmaps, the format GX's own sets use). The
busy cursors are 8-frame .ani files at 10 fps.
    cursors.py <out-dir>      writes <out>/cursors/*.cur|ani and prints the
                              manifest "items" list as JSON
"""
import io, json, math, os, struct, subprocess, sys
from PIL import Image

BONE, INK, CRIMSON, STORM, GOLD, EMBER, WINE = "#EDE3D1", "#0B0709", "#B3263A", "#D9474F", "#C9A45C", "#FF7A3D", "#2A1C25"
OUT = 1.5   # outline width (grid units)

def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32">{body}</svg>'

def diamond(cx, cy, r, fill=GOLD, stroke=INK, sw=1.0):
    return f'<path d="M{cx} {cy-r} L{cx+r} {cy} L{cx} {cy+r} L{cx-r} {cy} Z" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"/>'

ARROW = "M3 2 L3 24.5 L8.6 19.4 L12.3 27.6 L15.6 26.1 L12 18 L19.6 17.6 Z"
FACET = "M5.2 6.6 L5.2 19.6 L8.9 16.3 L15.1 15.9 Z"
def arrow(extra="", facet=CRIMSON):
    return (f'<path d="{ARROW}" fill="{BONE}" stroke="{INK}" stroke-width="{OUT}" stroke-linejoin="round"/>'
            f'<path d="{FACET}" fill="{facet}"/>' + extra)

def badge(content):   # a small wine plate at the arrow's lower right
    return f'<rect x="17" y="18.5" width="12" height="12" fill="{WINE}" stroke="{GOLD}" stroke-width="1.1"/>' + content

def double_arrow(angle, bars=False):
    shaft = '<path d="M4 16 L9 11 L9 14 L23 14 L23 11 L28 16 L23 21 L23 18 L9 18 L9 21 Z" ' \
            f'fill="{BONE}" stroke="{INK}" stroke-width="{OUT}" stroke-linejoin="round"/>' \
            f'<rect x="10" y="15.2" width="12" height="1.6" fill="{CRIMSON}"/>'
    if bars:
        shaft += f'<rect x="14.4" y="6" width="3.2" height="20" fill="{GOLD}" stroke="{INK}" stroke-width="1"/>'
    return f'<g transform="rotate({angle} 16 16)">{shaft}</g>'

def ibeam(angle=0):
    return (f'<g transform="rotate({angle} 16 16)"><path d="M11 4 L21 4 L21 6.6 L17.4 6.6 L17.4 25.4 L21 25.4 L21 28 L11 28 L11 25.4 L14.6 25.4 L14.6 6.6 L11 6.6 Z" '
            f'fill="{BONE}" stroke="{INK}" stroke-width="1.2" stroke-linejoin="round"/>'
            f'<rect x="15.4" y="8" width="1.2" height="16" fill="{CRIMSON}"/></g>')

def ring_slash():
    return (f'<circle cx="16" cy="16" r="10.5" fill="none" stroke="{INK}" stroke-width="6"/>'
            f'<circle cx="16" cy="16" r="10.5" fill="none" stroke="{STORM}" stroke-width="3.4"/>'
            f'<path d="M8.6 23.4 L23.4 8.6" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>'
            f'<path d="M8.6 23.4 L23.4 8.6" stroke="{STORM}" stroke-width="3.4" stroke-linecap="round"/>')

def magnifier(sign):
    s = (f'<path d="M20 20 L28 28" stroke="{INK}" stroke-width="6" stroke-linecap="round"/>'
         f'<path d="M20 20 L28 28" stroke="{GOLD}" stroke-width="3.2" stroke-linecap="round"/>'
         f'<circle cx="13" cy="13" r="9" fill="{WINE}" fill-opacity=".55" stroke="{INK}" stroke-width="4.4"/>'
         f'<circle cx="13" cy="13" r="9" fill="none" stroke="{BONE}" stroke-width="2"/>'
         f'<rect x="8.5" y="12" width="9" height="2" fill="{STORM}"/>')
    if sign == "+":
        s += f'<rect x="12" y="8.5" width="2" height="9" fill="{STORM}"/>'
    return s

def fourway():
    a = '<path d="M16 2 L21 8 L18 8 L18 14 L24 14 L24 11 L30 16 L24 21 L24 18 L18 18 L18 24 L21 24 L16 30 L11 24 L14 24 L14 18 L8 18 L8 21 L2 16 L8 11 L8 14 L14 14 L14 8 L11 8 Z"'
    return f'{a} fill="{BONE}" stroke="{INK}" stroke-width="1.3" stroke-linejoin="round"/>' + diamond(16, 16, 3.2)

def crosshair():
    lines = "".join(f'<path d="{d}" stroke="{INK}" stroke-width="3.6" stroke-linecap="round"/><path d="{d}" stroke="{BONE}" stroke-width="1.6" stroke-linecap="round"/>'
                    for d in ("M16 3 L16 11", "M16 21 L16 29", "M3 16 L11 16", "M21 16 L29 16"))
    return lines + diamond(16, 16, 2.6)

def spinner(frame, cx=16, cy=16, r=9, dot=2.6):   # 8 embers in a ring, the bright one advancing
    s = f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{INK}" stroke-width="{dot*2+2}" opacity=".55"/>'
    for i in range(8):
        a = math.pi * 2 * i / 8 - math.pi / 2
        age = (frame - i) % 8                      # 0 = brightest
        col = [EMBER, "#F0663A", STORM, CRIMSON, "#8E2234", "#6E1B2B", "#561626", "#451320"][age]
        rr = dot * (1.25 if age == 0 else 1.0 if age < 3 else 0.8)
        x, y = cx + r * math.cos(a), cy + r * math.sin(a)
        s += diamond(round(x, 2), round(y, 2), round(rr, 2), fill=col, stroke=INK, sw=0.6)
    return s

def hand():   # a link: the arrow with an ember facet and a gold diamond at its tip
    return arrow(diamond(19.5, 7, 3.6) + f'<circle cx="19.5" cy="7" r="6" fill="{EMBER}" opacity=".18"/>', facet=EMBER)

STATIC = {   # name: (svg, hotspot on the 32 grid)
    "pointer": (arrow(diamond(16.6, 25.2, 2.2)), (3, 2)),
    "link": (hand(), (3, 2)),
    "help": (arrow(badge(f'<text x="23" y="28.3" font-family="Cinzel" font-weight="700" font-size="11" fill="{GOLD}" text-anchor="middle">?</text>')), (3, 2)),
    "copy": (arrow(badge(f'<path d="M23 20.5 L23 28.5 M19 24.5 L27 24.5" stroke="{GOLD}" stroke-width="2"/>')), (3, 2)),
    "alias": (arrow(badge(f'<path d="M20 28 Q20 21.5 26 21.5" fill="none" stroke="{GOLD}" stroke-width="1.8"/><path d="M24 19.4 L27.2 21.5 L24 23.6 Z" fill="{GOLD}"/>')), (3, 2)),
    "context_menu": (arrow(badge("".join(f'<rect x="19.5" y="{y}" width="7" height="1.6" fill="{GOLD}"/>' for y in (21, 24, 27)))), (3, 2)),
    "text": (ibeam(), (16, 16)),
    "vertical_text": (ibeam(90), (16, 16)),
    "crosshair": (crosshair(), (16, 16)),
    "cell": (f'<path d="M12.5 4 L19.5 4 L19.5 12.5 L28 12.5 L28 19.5 L19.5 19.5 L19.5 28 L12.5 28 L12.5 19.5 L4 19.5 L4 12.5 L12.5 12.5 Z" fill="{BONE}" stroke="{INK}" stroke-width="1.4" stroke-linejoin="round"/>' + diamond(16, 16, 2.4, fill=CRIMSON), (16, 16)),
    "not_allowed": (ring_slash(), (16, 16)),
    "move": (fourway(), (16, 16)),
    "grab": (diamond(16, 16, 11, fill=WINE, stroke=INK, sw=2.6) + diamond(16, 16, 11, fill="none", stroke=GOLD, sw=1.4) + diamond(16, 16, 4.5, fill=BONE), (16, 16)),
    "grabbing": (diamond(16, 16, 8, fill=EMBER, stroke=INK, sw=2.2) + diamond(16, 16, 8, fill="none", stroke=GOLD, sw=1.1) + diamond(16, 16, 3, fill=BONE, sw=0.8), (16, 16)),
    "zoom_in": (magnifier("+"), (13, 13)),
    "zoom_out": (magnifier("-"), (13, 13)),
    "east_west_resize": (double_arrow(0), (16, 16)),
    "north_south_resize": (double_arrow(90), (16, 16)),
    "north_west_south_east_resize": (double_arrow(45), (16, 16)),
    "north_east_south_west_resize": (double_arrow(-45), (16, 16)),
    "column_resize": (double_arrow(0, bars=True), (16, 16)),
    "row_resize": (double_arrow(90, bars=True), (16, 16)),
}
ANIMATED = {
    "wait": ([spinner(f) for f in range(8)], (16, 16)),
    "progress": ([arrow() + f'<g transform="translate(13.5 13.5) scale(.55)">{spinner(f, 16, 16, 9, 3)}</g>' for f in range(8)], (3, 2)),
}
TYPES = {   # GX cursor type → file
    "POINTER": "pointer", "HAND": "link", "HELP": "help", "COPY": "copy", "ALIAS": "alias",
    "CONTEXT_MENU": "context_menu", "I_BEAM": "text", "VERTICAL_TEXT": "vertical_text", "CROSS": "crosshair",
    "CELL": "cell", "NOT_ALLOWED": "not_allowed", "NO_DROP": "not_allowed", "MOVE": "move", "GRAB": "grab",
    "GRABBING": "grabbing", "ZOOM_IN": "zoom_in", "ZOOM_OUT": "zoom_out", "WAIT": "wait", "PROGRESS": "progress",
    "EAST_WEST_RESIZE": "east_west_resize", "EAST_RESIZE": "east_west_resize", "WEST_RESIZE": "east_west_resize",
    "NORTH_SOUTH_RESIZE": "north_south_resize", "NORTH_RESIZE": "north_south_resize", "SOUTH_RESIZE": "north_south_resize",
    "NORTH_WEST_SOUTH_EAST_RESIZE": "north_west_south_east_resize", "NORTH_WEST_RESIZE": "north_west_south_east_resize",
    "SOUTH_EAST_RESIZE": "north_west_south_east_resize", "NORTH_EAST_SOUTH_WEST_RESIZE": "north_east_south_west_resize",
    "NORTH_EAST_RESIZE": "north_east_south_west_resize", "SOUTH_WEST_RESIZE": "north_east_south_west_resize",
    "COLUMN_RESIZE": "column_resize", "ROW_RESIZE": "row_resize",
}

def render(body, px):
    png = subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px)], input=svg(body).encode(), capture_output=True, check=True).stdout
    return Image.open(io.BytesIO(png)).convert("RGBA")

def bmp_entry(img):   # BITMAPINFOHEADER + bottom-up BGRA + empty AND mask
    w, h = img.size
    px = img.tobytes("raw", "BGRA")
    rows = [px[y * w * 4:(y + 1) * w * 4] for y in range(h)][::-1]
    mask_row = ((w + 31) // 32) * 4
    hdr = struct.pack("<IiiHHIIiiII", 40, w, h * 2, 1, 32, 0, len(px) + mask_row * h, 0, 0, 0, 0)
    return hdr + b"".join(rows) + b"\0" * (mask_row * h)

def cur(body, hot):
    imgs = [(s, bmp_entry(render(body, s))) for s in (32, 64)]
    out = struct.pack("<HHH", 0, 2, len(imgs))
    off = 6 + 16 * len(imgs)
    for s, data in imgs:
        k = s // 32
        out += struct.pack("<BBBBHHII", s, s, 0, 0, hot[0] * k, hot[1] * k, len(data), off)
        off += len(data)
    return out + b"".join(d for _, d in imgs)

def ani(frames, hot, jiffies=6):   # 6/60 s per frame = 10 fps
    icons = b"".join(b"icon" + struct.pack("<I", len(c)) + c + (b"\0" if len(c) & 1 else b"")
                     for c in (cur(f, hot) for f in frames))
    anih = struct.pack("<9I", 36, len(frames), len(frames), 0, 0, 0, 0, jiffies, 1)
    body = b"ACON" + b"anih" + struct.pack("<I", 36) + anih + b"LIST" + struct.pack("<I", 4 + len(icons)) + b"fram" + icons
    return b"RIFF" + struct.pack("<I", len(body)) + body

def sheet(path):   # preview: every cursor at 64 px on wine
    names = list(STATIC) + list(ANIMATED)
    cols = 6; rows = math.ceil(len(names) / cols)
    im = Image.new("RGBA", (512, 512), WINE)
    cell = 512 // cols
    for i, n in enumerate(names):
        body = STATIC[n][0] if n in STATIC else ANIMATED[n][0][0]
        g = render(body, 64)
        top = (512 - rows * cell) // 2
        im.alpha_composite(g, (i % cols * cell + (cell - 64) // 2, top + i // cols * cell + (cell - 64) // 2))
    im.convert("RGB").save(path)

if __name__ == "__main__":
    out = os.path.join(sys.argv[1], "cursors"); os.makedirs(out, exist_ok=True)
    for n, (body, hot) in STATIC.items():
        open(f"{out}/{n}.cur", "wb").write(cur(body, hot))
    for n, (frames, hot) in ANIMATED.items():
        open(f"{out}/{n}.ani", "wb").write(ani(frames, hot))
    sheet(os.path.join(out, "preview.jpg"))
    items = [{"type": t, "path": f"cursors/{f}.{'ani' if f in ANIMATED else 'cur'}"} for t, f in TYPES.items()]
    print(json.dumps(items))
