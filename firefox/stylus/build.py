#!/usr/bin/env python3
"""Turn a Catppuccin userstyle into a Lace & Ember one.

    build.py youtube            # build youtube.user.css from the cached upstream copy
    build.py youtube --fetch    # refresh the upstream copies first

Catppuccin's per-site styles (github.com/catppuccin/userstyles, MIT) colour
each site from 26 named colours. This adds a "lace" flavour holding the Lace &
Ember palette under those names, inlines Catppuccin's small Less library so
nothing is fetched at install time, and fixes the flavour to lace. The result
is still Less (`@preprocessor less`): Stylus compiles it when the style is
installed from a URL (serve.sh), and keeps the Crimson / Gold / Ember choice.
Optional extra CSS for a site goes in touches/<site>.css and is appended.
"""
import os, re, sys, time, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
UP = os.path.join(HERE, "upstream")
RAW = "https://raw.githubusercontent.com/catppuccin/userstyles/main/styles/{}/catppuccin.user.less"
STD = "https://userstyles.catppuccin.com/lib/std/v1.less"

# Lace & Ember under Catppuccin's names. Surfaces climb from obsidian through
# the dusk wine Dark Reader uses (#2A1C25); "blue" (links) turns gold.
LACE = {
    "rosewater": "#f1d9c7", "flamingo": "#e8b4a8", "pink": "#e59aa8", "mauve": "#c9a45c",
    "red": "#d9474f", "maroon": "#e06a6f", "peach": "#ff7a3d", "yellow": "#c9a45c",
    "green": "#a9b98a", "teal": "#8fb8a8", "sky": "#a9bccb", "sapphire": "#98aec4",
    "blue": "#d4b06a", "lavender": "#b58f62",
    "text": "#ede3d1", "subtext1": "#d3c9c4", "subtext0": "#b9b0b8",
    "overlay2": "#9c8b93", "overlay1": "#85707a", "overlay0": "#6e5560",
    "surface2": "#553846", "surface1": "#452e39", "surface0": "#36242e",
    "base": "#2a1c25", "mantle": "#1e1419", "crust": "#150d10",
}


def get(url, path):
    with urllib.request.urlopen(url) as r:
        open(path, "wb").write(r.read())


def main():
    site = sys.argv[1]
    os.makedirs(UP, exist_ok=True)
    src_path, std_path = os.path.join(UP, f"{site}.less"), os.path.join(UP, "std-v1.less")
    if "--fetch" in sys.argv or not os.path.exists(src_path):
        get(RAW.format(site), src_path)
    if "--fetch" in sys.argv or not os.path.exists(std_path):
        get(STD, std_path)
    src, std = open(src_path).read(), open(std_path).read()

    # 1. the library, with a lace flavour; icon filters borrow mocha's
    lace = "  @lace: { " + " ".join(f"@{k}: {v};" for k, v in LACE.items()) + " };\n"
    std = std.replace("@catppuccin: {\n", "@catppuccin: {\n" + lace, 1)
    mocha_f = re.search(r"^  @mocha: (\{.*\});$", std.split("@catppuccin-filters")[1], re.M).group(1)
    std = std.replace("@catppuccin-filters: {\n", "@catppuccin-filters: {\n  @lace: " + mocha_f + ";\n", 1)

    # 2. the header: our name, no flavour choice, a three-way accent
    meta = re.search(r"/\* ==UserStyle==\n(.*?)==/UserStyle== \*/", src, re.S).group(1)
    name = re.search(r"^@name (.*?) Catppuccin$", meta, re.M).group(1)
    keep = [l for l in meta.splitlines() if l.startswith("@var") and "Flavor" not in l and "accentColor" not in l]
    header = "\n".join([
        "/* ==UserStyle==",
        f"@name {name} · Lace & Ember",
        f"@namespace lace-ember/{site}",
        f"@version {time.strftime('%Y.%m.%d.%H%M')}",  # newer on every build, so Stylus offers the update
        f"@description {name} in the Lace & Ember palette: dusk wine, bone text, gold links, a crimson, gold or ember accent.",
        "@author Lace & Ember (colour rules from Catppuccin's userstyles, MIT, github.com/catppuccin/userstyles)",
        "@license MIT",
        "",
        "@preprocessor less",
        '@var select accentColor "Accent" ["red:Crimson*", "yellow:Gold", "peach:Ember"]',
        *keep,
        "==/UserStyle== */",
    ])
    body = src[src.index("==/UserStyle== */") + len("==/UserStyle== */"):]
    body = body.replace(f'@import "{STD}";', "")
    assert "@import" not in body, "upstream style imports something else; inline it"
    touches = os.path.join(HERE, "touches", f"{site}.css")
    extra = open(touches).read() if os.path.exists(touches) else ""

    out = (header + "\n\n@lightFlavor: lace;\n@darkFlavor: lace;\n\n"
           "/* Catppuccin's userstyle library (MIT), with the lace flavour added */\n"
           + std + "\n" + body.strip() + "\n" + (("\n" + extra) if extra else ""))
    dst = os.path.join(HERE, f"{site}.user.css")
    open(dst, "w").write(out)
    print(f"wrote {dst} ({len(out)} chars)")


if __name__ == "__main__":
    main()
