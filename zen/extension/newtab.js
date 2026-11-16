// Lace & Ember start page: clock, tiles, codex quote, embers.
const D = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"];
const M = ["January","February","March","April","May","June","July","August","September","October","November","December"];
function tick() {
  const n = new Date(), h = n.getHours() % 12 || 12;
  document.getElementById("clock").textContent = h + ":" + String(n.getMinutes()).padStart(2, "0");
  document.getElementById("date").textContent = D[n.getDay()] + " · " + n.getDate() + " " + M[n.getMonth()];
}
tick(); setInterval(tick, 10000);

const nav = document.getElementById("sites");
(window.SITES || []).forEach(s => {
  const a = document.createElement("a");
  a.className = "site"; a.href = s.url;
  a.innerHTML = '<span class="tile"></span><span class="lbl"></span>';
  a.querySelector(".tile").textContent = s.glyph;
  a.querySelector(".lbl").textContent = s.name;
  nav.appendChild(a);
});

// The quote: the same pick the desktop's codex.py makes, from the bundled pool
// (codex-pool.js, rebuilt by build.sh). Every 10 minutes: SHA-1 of the slot
// number picks a file, then a sentence in it.
async function codex() {
  const pool = window.CODEX_POOL;
  if (!pool || !pool.length) return;
  const slot = Math.floor(Date.now() / 1000 / 600);
  const buf = await crypto.subtle.digest("SHA-1", new TextEncoder().encode(String(slot)));
  const h = BigInt("0x" + [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, "0")).join(""));
  const n = BigInt(pool.length);
  const lines = pool[Number(h % n)];
  const c = lines[Number((h / n) % BigInt(lines.length))];
  document.getElementById("codex-text").textContent = "“" + c.text + "”";
  document.getElementById("codex-src").textContent = "— " + c.title + " · " + c.folder;
  document.getElementById("codex").hidden = false;
}
codex();

const em = document.getElementById("embers");
let seed = 5; const rnd = () => (seed = (seed * 9301 + 49297) % 233280) / 233280;
for (let i = 0; i < 18; i++) {
  const e = document.createElement("i"), s = 1.5 + rnd() * 2.5;
  Object.assign(e.style, { left: (rnd() * 100) + "%", width: s + "px", height: s + "px",
    animationDuration: (9 + rnd() * 9) + "s", animationDelay: "-" + (rnd() * 16) + "s" });
  em.appendChild(e);
}
