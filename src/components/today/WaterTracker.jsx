import Card from "../Card";
import ProgressRing from "../ProgressRing";

export default function WaterTracker({ oz, target, onAdd, onReset }) {
  const pct = target > 0 ? Math.round((oz / target) * 100) : 0;
  return (
    <Card title="Water">
      <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
        <ProgressRing
          value={oz}
          max={target}
          size={96}
          color="var(--teal)"
          centerNum={`${pct}%`}
        />
        <div style={{ flex: 1 }}>
          <div className="water-num">
            {oz}
            <span className="target"> / {target} oz</span>
          </div>
          <div className="note" style={{ marginTop: 4 }}>
            {oz >= target
              ? "Target hit. Nice."
              : `${target - oz} oz to go today.`}
          </div>
        </div>
      </div>
      <div className="water-btns">
        <button className="btn teal" onClick={() => onAdd(8)}>
          + 8 oz
        </button>
        <button className="btn ghost" onClick={onReset}>
          Reset
        </button>
      </div>
    </Card>
  );
}
