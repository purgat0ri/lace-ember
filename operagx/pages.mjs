// Turn the Stylus styles in ../firefox/stylus into GX page styles.
// Each @-moz-document block becomes one CSS file plus Chrome-style match
// patterns (GX can't read @-moz-document). Less styles are compiled first,
// with every @var at its default (the crimson accent).
//   node pages.mjs <out-dir> <lessc>      prints the page_styles JSON
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const [out, lessc] = process.argv.slice(2);
const SITES = ["youtube", "google", "duckduckgo", "reddit"];
const TLDS = ["com", "com.au", "com.sg", "co.uk"];   // GX patterns can't wildcard a TLD
const google = (subs) => TLDS.flatMap(t => subs.map(s => `https://${s}google.${t}/*`));
const REGEXPS = {
  "^https?://(www\\.|images\\.)?google\\..*": google(["", "www.", "images."]),
  "^https?://(ogs\\.)?google\\..*": google(["", "ogs."]),
};

function matches(cond) {
  const pats = [];
  for (const m of cond.matchAll(/(domain|url-prefix|url|regexp)\(\s*(["'])(.*?)\2\s*\)/g)) {
    const [, fn, , v] = m;
    if (fn === "domain") pats.push(`https://${v}/*`, `https://*.${v}/*`);
    else if (fn === "url-prefix") pats.push(v.replace(/\/?$/, "/") + "*");
    else if (fn === "url") pats.push(v);
    else {
      const key = v.replace(/\\\\/g, "\\");
      if (!REGEXPS[key]) throw new Error(`no match patterns for regexp ${v}`);
      pats.push(...REGEXPS[key]);
    }
  }
  return [...new Set(pats)];
}

function blocks(css) {      // [{cond, body}] for each top-level @-moz-document
  const res = [];
  let i = 0;
  while ((i = css.indexOf("@-moz-document", i)) !== -1) {
    const open = css.indexOf("{", i);
    let depth = 1, j = open + 1;
    for (; j < css.length && depth; j++) {
      if (css[j] === "{") depth++; else if (css[j] === "}") depth--;
      else if (css[j] === '"' || css[j] === "'") { const q = css[j]; j++; while (css[j] !== q) { if (css[j] === "\\") j++; j++; } }
    }
    res.push({ cond: css.slice(i + 14, open).trim(), body: css.slice(open + 1, j - 1).trim() });
    i = j;
  }
  return res;
}

function defaults(src) {     // Less definitions for each @var's default
  const meta = (src.match(/==UserStyle==([\s\S]*?)==\/UserStyle==/) || ["", ""])[1];
  const defs = [];
  for (const l of meta.split("\n")) {
    const m = l.match(/^@var\s+(\w+)\s+(\w+)\s+"[^"]*"\s+(.*)$/);
    if (!m) continue;
    const [, type, name, rest] = m;
    let v = rest.trim();
    if (type === "select") {
      const items = JSON.parse(v);
      const pick = items.find(x => x.endsWith("*")) || items[0];
      v = pick.replace(/\*$/, "").split(":")[0];
    }
    defs.push(`@${name}: ${v};`);
  }
  return defs.join("\n");
}

mkdirSync(join(out, "pages"), { recursive: true });
const styles = [];
for (const site of SITES) {
  let src = readFileSync(join(here, "..", "firefox", "stylus", `${site}.user.css`), "utf8");
  let css = src;
  if (/@preprocessor\s+less/.test(src)) {
    const body = defaults(src) + "\n" + src.replace(/\/\* ==UserStyle==[\s\S]*?==\/UserStyle== \*\//, "");
    const [cmd, ...args] = lessc.split(" ");
    css = execFileSync(cmd, [...args, "-"], { input: body, maxBuffer: 64 << 20 }).toString();
  }
  blocks(css).forEach((b, n) => {
    const file = `pages/${site}${n ? "-" + (n + 1) : ""}.css`;
    writeFileSync(join(out, file), `/* ${site}: Lace & Ember (colour rules from Catppuccin's userstyles, MIT) */\n${b.body}\n`);
    const label = { youtube: "YouTube", google: "Google", duckduckgo: "DuckDuckGo", reddit: "Reddit" }[site];
    styles.push({ id: `lace_ember_${site}${n ? "_" + (n + 1) : ""}`, name: `${label}${n ? " " + (n + 1) : ""} · Lace & Ember`,
                  css: [file], matches: matches(b.cond) });
  });
}
console.log(JSON.stringify(styles));
