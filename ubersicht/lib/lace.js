// Lace & Ember — shared tokens and the "block" every widget is built from.
import { css } from "uebersicht";

export const C = {
  ink: "#0B0709",
  obsidian: "#150D10",
  crimson: "#B3263A",
  storm: "#D9474F",
  ember: "#FF7A3D",
  gold: "#C9A45C",
  bone: "#EDE3D1",
  ash: "#B9B0B8",
  glow: "rgba(179,38,58,0.6)",
};

export const F = {
  deco: "'Cinzel Decorative', Cinzel, serif",
  display: "Cinzel, serif",
  ui: "'Inter Tight', -apple-system, sans-serif",
  mono: "'JetBrains Mono', ui-monospace, monospace",
};

const g = C.gold;
const corners = [
  "top left/12px 1px", "top left/1px 12px",
  "top right/12px 1px", "top right/1px 12px",
  "bottom left/12px 1px", "bottom left/1px 12px",
  "bottom right/12px 1px", "bottom right/1px 12px",
].map((p) => `linear-gradient(${g},${g}) ${p} no-repeat`).join(",");

// The block: obsidian glass, bone hairline, black outline, gold corner pins,
// crimson underglow. Add `pin` for the diamond lace pin at top centre.
export const block = css`
  position: absolute;
  box-sizing: border-box;
  color: ${C.bone};
  font-family: ${F.ui};
  background: rgba(13, 8, 10, 0.8);
  -webkit-backdrop-filter: blur(16px) saturate(125%);
  backdrop-filter: blur(16px) saturate(125%);
  border: 1px solid rgba(237, 227, 209, 0.42);
  outline: 1px solid rgba(0, 0, 0, 0.85);
  box-shadow: 0 0 0 4px rgba(10, 6, 8, 0.32), 0 16px 40px -12px ${C.glow},
    inset 0 1px 0 rgba(237, 227, 209, 0.07);
  animation: laceFlare 0.9s ease-out both;
  &::before {
    content: "";
    position: absolute;
    inset: 5px;
    pointer-events: none;
    background: ${corners};
    opacity: 0.85;
  }
  @keyframes laceFlare {
    0% { transform: scale(0.94); opacity: 0; filter: brightness(2); }
    45% { opacity: 1; filter: brightness(1.4); }
    100% { transform: scale(1); filter: brightness(1); }
  }
`;

export const pin = css`
  &::after {
    content: "";
    position: absolute;
    top: -5px;
    left: 50%;
    width: 8px;
    height: 8px;
    transform: translateX(-50%) rotate(45deg);
    background: #0d080a;
    border: 1px solid ${C.gold};
    box-shadow: 0 0 8px rgba(255, 122, 61, 0.5);
  }
`;

export const label = css`
  font-family: ${F.display};
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.24em;
  text-transform: uppercase;
  color: ${C.gold};
`;
