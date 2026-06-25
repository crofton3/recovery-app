import Card from "../Card";
import ProgressBar from "../ProgressBar";

function Cell({ label, value, target, unit }) {
  const pct = target > 0 ? Math.round((value / target) * 100) : 0;
  return (
    <div className="macro-cell">
      <div className="macro-top">
        <span className="macro-label">{label}</span>
        <span className="macro-pct">{pct}%</span>
      </div>
      <div className="macro-value">
        {value}
        <span className="target">
          {" "}
          / {target}
          {unit}
        </span>
      </div>
      <ProgressBar value={value} max={target} color="amber" />
    </div>
  );
}

export default function MacroDashboard({ totals, settings }) {
  return (
    <Card title="Today's Macros">
      <div className="macro-grid">
        <Cell
          label="Calories"
          value={totals.calories}
          target={settings.calorie_target}
          unit=""
        />
        <Cell
          label="Protein"
          value={totals.protein}
          target={settings.protein_target}
          unit="g"
        />
        <Cell
          label="Carbs"
          value={totals.carbs}
          target={settings.carbs_target}
          unit="g"
        />
        <Cell label="Fat" value={totals.fat} target={settings.fat_target} unit="g" />
      </div>
    </Card>
  );
}
