#!/usr/bin/env python3
"""Codex card: one sentence from the Abednego lore, quoted verbatim, with its file.

Source: every *.md under ~/Craft/Abednego/Lore. Only Markdown markup is removed
(bold/italic markers, the @ of mentions); words are never changed or joined, so
each quote is a real sentence from a named file. Headings, bullets, tables and
block quotes are skipped, so dossier fragments don't show up as lore.

The pick changes every 10 minutes and is the same for every call in that window.
Prints JSON: {"text", "title", "folder", "path"} or null.
"""
import hashlib, json, os, re, sys, time

LORE = os.path.expanduser(os.environ.get("LACE_CODEX_DIR") or "~/Craft/Abednego/Lore")
CACHE = os.path.expanduser("~/.cache/lace-ember/codex-pool.json")
SLOT = 600
MIN_LEN, MAX_LEN = 60, 210
# planning notes and cast indexes, not in-world text
SKIP_FOLDERS = {"Cast", "Story lore"}

SKIP_LINE = re.compile(r"^\s*(#|[-*+•]\s|\d+[.)]\s|\||>|```|---|!\[)")
SENT_SPLIT = re.compile(r"(?:(?<=[.!?])|(?<=[.!?][\"”’)]))\s+(?=[\"“‘(]?[A-Z])")


def clean(s: str) -> str:
    s = re.sub(r"\\(?=\s|$)", "", s)                       # Markdown hard line break: "text\"
    s = re.sub(r"\\([\\`*_{}\[\]()#+\-.!>~|\"'])", r"\1", s)  # Markdown escapes: "\*" -> "*"
    s = re.sub(r"\*\*|__|(?<!\w)[*_](?=\S)|(?<=\S)[*_](?!\w)", "", s)
    s = re.sub(r"@(?=[A-Z])", "", s)
    s = re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", s)
    return re.sub(r"\s+", " ", s).strip()


def title_of(text: str, path: str) -> str:
    m = re.search(r"^name:\s*(.+)$", text, re.M)
    return m.group(1).strip().strip("'\"") if m else os.path.basename(path).split(".")[0]


def sentences(path: str):
    text = open(path, encoding="utf-8").read()
    title = title_of(text, path)
    body = re.sub(r"\A---\n.*?\n---\n", "", text, flags=re.S)
    for para in re.split(r"\n\s*\n", body):
        # a line that is entirely bold is a heading, not prose: drop it
        lines = [l for l in para.splitlines() if l.strip() and not re.fullmatch(r"\s*\*\*[^*]+\*\*\s*", l)]
        if not lines or any(SKIP_LINE.match(l) for l in lines):
            continue
        para = clean(" ".join(lines))
        if ":" in para[:40] and para.count(":") >= 1 and len(para) < 80:
            continue  # "Label: value" lines
        for s in SENT_SPLIT.split(para):
            s = s.strip()
            if not (MIN_LEN <= len(s) <= MAX_LEN):
                continue
            if not re.search(r"[.!?][\"”’)]?$", s) or re.search(r"https?:|\{\{|\[|\]|\|", s):
                continue
            if s.count('"') % 2 or s.count("“") != s.count("”"):
                continue  # half a quotation
            yield {"text": s, "title": title,
                   "folder": os.path.relpath(os.path.dirname(path), LORE).split(os.sep)[0],
                   "path": path}


def pool():
    files = sorted(os.path.join(d, f) for d, _, fs in os.walk(LORE) for f in fs if f.endswith(".md")
                   and os.path.relpath(d, LORE).split(os.sep)[0] not in SKIP_FOLDERS)
    sig = hashlib.sha1("".join(f"{f}{os.path.getmtime(f)}" for f in files).encode()).hexdigest()
    try:
        c = json.load(open(CACHE))
        if c.get("sig") == sig:
            return c["items"]
    except Exception:
        pass
    items = [s for f in files for s in sentences(f)]
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    json.dump({"sig": sig, "items": items}, open(CACHE, "w"))
    return items


if __name__ == "__main__":
    items = pool() if os.path.isdir(LORE) else []
    if "--greet" in sys.argv:
        # a random line for a new terminal window: bone text, source in ash,
        # wrapped to the terminal and indented like a quote
        import random, shutil, textwrap
        if not items:
            sys.exit()
        files = {}
        for i in items:
            files.setdefault(i["path"], []).append(i)
        c = random.choice(random.choice(list(files.values())))
        width = min(shutil.get_terminal_size((80, 24)).columns, 96)
        bone, ash, gold, off = "\033[38;2;237;227;209m", "\033[38;2;185;176;184m", "\033[38;2;201;164;92m", "\033[0m"
        lines = textwrap.wrap("“" + c["text"] + "”", width - 6)
        print()
        for l in lines:
            print("  " + bone + l + off)
        src = "— " + c["title"] + " · " + c["folder"]
        print(" " * max(2, width - 2 - len(src)) + ash + src + off)
        print()
        sys.exit()
    if "--pool-js" in sys.argv:
        # for the Zen start page: the same pool, grouped by file in pick order,
        # so the page can make the same pick in JavaScript without a fetch
        by_file = {}
        for i in items:
            by_file.setdefault(i["path"], []).append({"text": i["text"], "title": i["title"], "folder": i["folder"]})
        pool = [by_file[p] for p in sorted(by_file)]
        print("window.CODEX_POOL = " + json.dumps(pool, ensure_ascii=False) + ";")
        sys.exit()
    if "--all" in sys.argv:
        for i in items:
            print(f"[{i['folder']} / {i['title']}] {i['text']}")
        sys.exit()
    if not items:
        print("null"); sys.exit()
    slot = int(time.time() // SLOT)
    # pick a file, then a sentence in it, so long stories don't dominate
    by_file = {}
    for i in items:
        by_file.setdefault(i["path"], []).append(i)
    paths = sorted(by_file)
    h = int(hashlib.sha1(str(slot).encode()).hexdigest(), 16)
    lines = by_file[paths[h % len(paths)]]
    pick = lines[(h // len(paths)) % len(lines)]
    print(json.dumps(pick, ensure_ascii=False))
