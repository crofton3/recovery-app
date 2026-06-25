import Card from "../Card";
import { MEALS } from "../../lib/constants";
import { isPtDay } from "../../lib/date";

function Chip({ on, color, warn, children }) {
  const cls = warn ? "chip warn" : `chip ${color} ${on ? "on" : ""}`;
  return (
    <span className={cls}>
      <span className="dot" />
      {children}
    </span>
  );
}

export default function RecoveryChips({ totals, status, settings }) {
  const proteinOk = totals.protein >= settings.protein_target;
  const waterOk = (status.water_oz || 0) >= settings.water_target_oz;
  const collagenOk = !!status.collagen_taken;
  const mealsDone = MEALS.filter((m) => status.meals_checked?.[m.key]).length;
  const allMeals = mealsDone === MEALS.length;
  const ptDay = isPtDay();

  return (
    <Card title="Recovery Checklist">
      <div className="chips">
        <Chip on={proteinOk} color="amber">
          Protein {proteinOk ? "on track" : `${totals.protein}/${settings.protein_target}g`}
        </Chip>
        <Chip on={waterOk} color="teal">
          Water {waterOk ? "on track" : `${status.water_oz || 0}/${settings.water_target_oz}oz`}
        </Chip>
        <Chip on={collagenOk} color="teal">
          {collagenOk ? "Collagen done" : "Collagen pending"}
        </Chip>
        <Chip on={allMeals} color="amber">
          Meals {mealsDone}/{MEALS.length}
        </Chip>
        {ptDay && (
          <Chip on color="teal">
            PT day
          </Chip>
        )}
      </div>
    </Card>
  );
}
