// Right-hand column: the sky, now playing, next deeds (OmniFocus · Abednego).
import { css, run } from "uebersicht";
import { C, F, block, pin, label } from "./lib/lace.js";

export const command = "./lib/column.sh";
export const refreshFrequency = 3000;

export const className = css`
  position: absolute;
  top: 52px;
  right: 36px;
  width: 380px;
  display: flex;
  flex-direction: column;
  gap: 22px;
  z-index: 1;
  @keyframes laceWave { 0%, 100% { transform: scaleY(0.22); } 50% { transform: scaleY(1); } }
`;

const card = css`
  position: relative !important;
`;
const ash = { color: C.ash };
const display = (size, weight = 500) => ({ fontFamily: F.display, fontSize: size, fontWeight: weight });

const waveBar = css`
  display: block;
  width: 4px;
  height: 34px;
  border-radius: 2px;
  background: linear-gradient(${C.ember}, ${C.crimson});
  transform-origin: bottom;
  animation: laceWave 1.1s ease-in-out infinite;
`;
let seed = 11;
const rnd = () => ((seed = (seed * 9301 + 49297) % 233280), seed / 233280);
const WAVE = Array.from({ length: 40 }, () => ({
  animationDelay: `-${(rnd() * 1.1).toFixed(2)}s`,
  animationDuration: `${(0.8 + rnd() * 0.7).toFixed(2)}s`,
}));

const mmss = (s) => `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;

// wttr.in weather codes → glyph family
const kind = (code) => {
  const c = Number(code);
  if ([200, 386, 389, 392, 395].includes(c)) return "storm";
  if ([113].includes(c)) return "clear";
  if ([116].includes(c)) return "part";
  if ([143, 248, 260].includes(c)) return "fog";
  if ((c >= 179 && c <= 230) || (c >= 317 && c <= 338) || (c >= 362 && c <= 377)) return "snow";
  if (c >= 176) return "rain";
  return "cloud";
};

const Sky = ({ k }) => {
  const cloud = <path d="M14 30h20a8 8 0 0 0 0-16 11 11 0 0 0-21 3 6.5 6.5 0 0 0 1 13z" />;
  const extra = {
    storm: <path d="M24 31l-4 7h6l-3 7" stroke={C.ember} strokeWidth="2" />,
    rain: <path d="M17 35l-2 5M24 35l-2 5M31 35l-2 5" stroke={C.ember} />,
    snow: <path d="M17 37h.01M24 40h.01M31 37h.01" stroke={C.ember} strokeWidth="3" />,
    fog: <path d="M12 36h24M16 41h16" stroke={C.ember} />,
  }[k];
  if (k === "clear")
    return (
      <svg width="58" height="58" viewBox="0 0 48 48" fill="none" stroke={C.bone} strokeWidth="1.6" strokeLinecap="round">
        <circle cx="24" cy="24" r="8" stroke={C.ember} />
        <path d="M24 6v5M24 37v5M6 24h5M37 24h5M11 11l3.5 3.5M33.5 33.5L37 37M11 37l3.5-3.5M33.5 14.5L37 11" />
      </svg>
    );
  return (
    <svg width="58" height="58" viewBox="0 0 48 48" fill="none" stroke={C.bone} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      {k === "part" && <path d="M30 8a7 7 0 0 1 9 9" stroke={C.ember} />}
      {cloud}
      {extra}
    </svg>
  );
};

export const render = ({ output, error }) => {
  let d = {};
  try { d = JSON.parse(output || "{}"); } catch (e) { d = {}; }
  const w = d.weather, np = d.np, tasks = d.tasks, codex = d.codex;
  const playing = np && np.state === "playing";
  const pct = np && np.dur ? Math.min(100, (np.pos / np.dur) * 100) : 0;

  return (
    <div style={{ display: "contents" }}>
      <section className={`${block} ${pin} ${card}`} style={{ padding: "20px 22px", display: "flex", alignItems: "center", gap: 18 }}>
        <Sky k={w ? kind(w.code) : "cloud"} />
        <div style={{ display: "flex", flexDirection: "column", gap: 2, flex: 1, minWidth: 0 }}>
          <span className={label}>The sky</span>
          <span style={{ ...display(40), lineHeight: 1 }}>{w ? `${w.temp}°` : "—"}</span>
          <span style={{ ...ash, fontSize: 13, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
            {w ? `${w.desc} · ${w.hi}° / ${w.lo}°` : "Reading the sky…"}
          </span>
        </div>
      </section>

      <section className={`${block} ${card}`} style={{ padding: "18px 20px", display: "flex", flexDirection: "column", gap: 14 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
          <span className={label}>{np ? (playing ? "Now playing" : "Paused") : "Silence"}</span>
          {np && <span style={{ ...ash, fontSize: 11, letterSpacing: "0.06em" }}>{np.app}</span>}
        </div>
        <div style={{ display: "flex", gap: 14, alignItems: "center" }}>
          {d.art ? (
            // medium tint: half-desaturated toward crimson-sepia, darkened at the foot
            <div style={{ position: "relative", width: 64, height: 64, flex: "none", overflow: "hidden",
              border: "1px solid rgba(237,227,209,.35)", outline: "1px solid rgba(0,0,0,.85)",
              boxShadow: `0 6px 18px -6px ${C.glow}` }}>
              <img src={d.art} alt="" style={{ width: "100%", height: "100%", objectFit: "cover", display: "block",
                filter: "grayscale(.5) sepia(.35) saturate(1.3) hue-rotate(-22deg) brightness(.9) contrast(1.05)" }} />
              <span style={{ position: "absolute", inset: 0,
                background: "linear-gradient(180deg, rgba(11,7,9,0), rgba(11,7,9,.35))" }} />
            </div>
          ) : (
          <div style={{ width: 64, height: 64, flex: "none", background: "radial-gradient(circle at 35% 30%, #5a1a24, #12090c 70%)",
            border: "1px solid rgba(237,227,209,.35)", display: "flex", alignItems: "center", justifyContent: "center" }}>
            <svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke={C.gold} strokeWidth="1.5"
              style={playing ? { animation: "laceSpin 6s linear infinite" } : {}}>
              <circle cx="12" cy="12" r="9" /><circle cx="12" cy="12" r="2.5" /><path d="M12 3a9 9 0 0 1 9 9" stroke={C.ember} />
            </svg>
            <style>{"@keyframes laceSpin{to{transform:rotate(360deg)}}"}</style>
          </div>
          )}
          <div style={{ display: "flex", flexDirection: "column", gap: 3, minWidth: 0 }}>
            <span style={{ ...display(16, 600), whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
              {np ? np.title : "Nothing playing"}
            </span>
            <span style={{ ...ash, fontSize: 13, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
              {np ? `${np.artist} · ${np.album}` : "The storm is quiet"}
            </span>
          </div>
        </div>
        <div style={{ display: "flex", alignItems: "flex-end", gap: 4, height: 34 }}>
          {WAVE.map((s, i) => (
            <span key={i} className={waveBar}
              style={playing ? s : { ...s, animationPlayState: "paused", opacity: 0.35 }} />
          ))}
        </div>
        {np && (
          <div style={{ display: "flex", alignItems: "center", gap: 10, fontSize: 11.5, fontFamily: F.mono, ...ash }}>
            <span>{mmss(np.pos)}</span>
            <span style={{ flex: 1, height: 2, background: "rgba(237,227,209,.18)", position: "relative" }}>
              <span style={{ position: "absolute", left: 0, top: 0, bottom: 0, width: `${pct}%`,
                background: `linear-gradient(90deg, ${C.crimson}, ${C.ember})`, boxShadow: `0 0 8px ${C.ember}`,
                transition: "width 3s linear" }} />
            </span>
            <span>{mmss(np.dur)}</span>
          </div>
        )}
      </section>

      <section className={`${block} ${card}`} style={{ padding: "18px 20px", display: "flex", flexDirection: "column", gap: 12 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
          <span className={label}>Next deeds</span>
          <span style={{ ...ash, fontSize: 11, letterSpacing: "0.06em" }}>OmniFocus · Abednego</span>
        </div>
        {tasks && tasks.length ? (
          tasks.map((t, i) => (
            <div key={i} style={{ display: "flex", alignItems: "center", gap: 12, fontSize: 14, lineHeight: 1.35 }}>
              <span style={{ width: 9, height: 9, flex: "none", transform: "rotate(45deg)", border: `1px solid ${C.gold}` }} />
              <span>{t}</span>
            </div>
          ))
        ) : (
          <span style={{ ...ash, fontSize: 13 }}>{tasks ? "No deeds await." : "OmniFocus is closed."}</span>
        )}
      </section>

      {codex && (
        <section className={`${block} ${card}`} title={codex.path}
          onClick={() => run(`open -R ${JSON.stringify(codex.path)}`)}
          style={{ padding: "20px 24px", display: "flex", flexDirection: "column", gap: 10,
            alignItems: "center", textAlign: "center", cursor: "pointer" }}>
          <span className={label}>From the codex</span>
          <p style={{ margin: 0, fontFamily: F.display, fontSize: 15, lineHeight: 1.6, color: C.bone }}>
            “{codex.text}”
          </p>
          <span style={{ ...ash, fontSize: 11.5 }}>— {codex.title} · {codex.folder}</span>
        </section>
      )}
    </div>
  );
};
