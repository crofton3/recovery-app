export default function ProgressBar({ value, max, color = "amber" }) {
  const pct = max > 0 ? (value / max) * 100 : 0;
  const over = pct > 100;
  const width = Math.min(100, pct);
  return (
    <div className={`bar ${over ? "over" : color}`}>
      <span style={{ width: `${width}%` }} />
    </div>
  );
}
