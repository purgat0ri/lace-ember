// "The hour": big Cinzel clock with the date between gold rules.
import { css, React } from "uebersicht";
import { C, F, block, pin, label } from "./lib/lace.js";

export const refreshFrequency = false;
export const command = undefined;

export const className = css`
  position: absolute;
  top: 52px;
  left: 36px;
  z-index: 1;
`;

const DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
const MONTHS = ["January", "February", "March", "April", "May", "June", "July",
  "August", "September", "October", "November", "December"];

const box = css`
  position: relative !important;
  width: 420px;
  padding: 26px 30px 24px;
  display: flex;
  flex-direction: column;
  gap: 6px;
`;
const time = css`
  font-family: ${F.display};
  font-weight: 500;
  font-size: 104px;
  line-height: 0.95;
  letter-spacing: 0.02em;
  color: ${C.bone};
  text-shadow: 0 0 28px ${C.glow};
`;
const rule = (dir) => css`
  height: 1px;
  flex: 1;
  background: linear-gradient(${dir}, rgba(201, 164, 92, 0), ${C.gold});
`;

const Clock = () => {
  const [now, setNow] = React.useState(new Date());
  React.useEffect(() => {
    // tick on the minute boundary, then every minute
    let iv;
    const t = setTimeout(() => {
      setNow(new Date());
      iv = setInterval(() => setNow(new Date()), 60000);
    }, 60000 - (Date.now() % 60000) + 50);
    return () => { clearTimeout(t); clearInterval(iv); };
  }, []);
  let h = now.getHours();
  const ampm = h >= 12 ? "PM" : "AM";
  h = h % 12 || 12;
  const mm = String(now.getMinutes()).padStart(2, "0");
  return (
    <section className={`${block} ${pin} ${box}`}>
      <span className={label}>The hour</span>
      <div style={{ display: "flex", alignItems: "baseline", gap: 10 }}>
        <span className={time}>{h}:{mm}</span>
        <span style={{ fontFamily: F.display, fontSize: 20, fontWeight: 600, color: C.gold }}>{ampm}</span>
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: 12, marginTop: 6 }}>
        <span className={rule("90deg")} />
        <span style={{ fontFamily: F.display, fontSize: 14, fontWeight: 600, letterSpacing: "0.26em",
          textTransform: "uppercase", whiteSpace: "nowrap" }}>
          {DAYS[now.getDay()]} · {now.getDate()} {MONTHS[now.getMonth()]}
        </span>
        <span className={rule("270deg")} />
      </div>
    </section>
  );
};

export const render = () => <Clock />;
