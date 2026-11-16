// Embers drifting up over the whole desktop, above the live wallpaper.
// Pure CSS animation: no command, no refresh. Count kept low for the M1 Air.
import { css } from "uebersicht";

export const refreshFrequency = false;
export const command = undefined;

export const className = css`
  position: fixed;
  inset: 0;
  pointer-events: none;
  overflow: hidden;
  z-index: 0;
  @keyframes emberRise {
    0% { transform: translate(0, 0) scale(1); opacity: 0; }
    8% { opacity: 1; }
    55% { transform: translate(18px, -50vh) scale(0.85); }
    100% { transform: translate(-14px, -104vh) scale(0.4); opacity: 0; }
  }
`;

const ember = css`
  position: absolute;
  bottom: -12px;
  border-radius: 50%;
  background: #ffb27a;
  box-shadow: 0 0 6px 2px rgba(255, 122, 61, 0.75), 0 0 14px 4px rgba(179, 38, 58, 0.35);
  animation-name: emberRise;
  animation-timing-function: linear;
  animation-iteration-count: infinite;
  will-change: transform, opacity;
`;

let seed = 7;
const rnd = () => ((seed = (seed * 9301 + 49297) % 233280), seed / 233280);
const EMBERS = Array.from({ length: 26 }, () => {
  const s = 1.5 + rnd() * 3;
  return {
    left: `${(rnd() * 100).toFixed(1)}%`,
    width: `${s.toFixed(1)}px`,
    height: `${s.toFixed(1)}px`,
    animationDuration: `${(10 + rnd() * 10).toFixed(1)}s`,
    animationDelay: `-${(rnd() * 20).toFixed(1)}s`,
  };
});

export const render = () => (
  <div>
    {EMBERS.map((style, i) => (
      <span key={i} className={ember} style={style} />
    ))}
  </div>
);
