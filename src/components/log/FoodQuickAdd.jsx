import Card from "../Card";
import { PRESET_FOODS } from "../../lib/constants";

export default function FoodQuickAdd({ onAdd }) {
  return (
    <Card title="Quick Add">
      <div className="quick-grid">
        {PRESET_FOODS.map((f) => (
          <button
            key={f.name}
            className="quick-btn"
            onClick={() =>
              onAdd({
                item_name: f.name,
                calories: f.calories,
                protein: f.protein,
                carbs: f.carbs,
                fat: f.fat,
              })
            }
          >
            <div className="quick-name">{f.name}</div>
            <div className="quick-macros">
              <b>{f.calories}</b> cal · {f.protein}p · {f.carbs}c · {f.fat}f
            </div>
          </button>
        ))}
      </div>
    </Card>
  );
}
