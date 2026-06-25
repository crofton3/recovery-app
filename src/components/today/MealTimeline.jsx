import Card from "../Card";
import { MEALS } from "../../lib/constants";

export default function MealTimeline({ checked, onToggle }) {
  const doneCount = MEALS.filter((m) => checked[m.key]).length;
  return (
    <Card title={`Meal Plan · ${doneCount}/${MEALS.length}`}>
      {MEALS.map((m) => {
        const on = !!checked[m.key];
        return (
          <div className="meal-row" key={m.key} onClick={() => onToggle(m.key)}>
            <div className={`check ${on ? "on" : ""}`}>✓</div>
            <div className="meal-info">
              <div className={`meal-name ${on ? "done" : ""}`}>{m.name}</div>
              <div className="meal-meta">{m.time}</div>
            </div>
            <div className="meal-macros">
              {m.cal} cal · {m.protein}g
            </div>
          </div>
        );
      })}
    </Card>
  );
}
