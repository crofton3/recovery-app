import { useState } from "react";
import Card from "../Card";

const EMPTY = { item_name: "", calories: "", protein: "", carbs: "", fat: "" };

export default function CustomFoodForm({ onAdd }) {
  const [form, setForm] = useState(EMPTY);
  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  const submit = async (e) => {
    e.preventDefault();
    if (!form.item_name.trim()) return;
    await onAdd({
      item_name: form.item_name.trim(),
      calories: form.calories,
      protein: form.protein,
      carbs: form.carbs,
      fat: form.fat,
    });
    setForm(EMPTY);
  };

  return (
    <Card title="Custom Food">
      <form onSubmit={submit}>
        <div className="field">
          <label>Food name</label>
          <input
            className="input"
            placeholder="e.g. Turkey wrap"
            value={form.item_name}
            onChange={(e) => set("item_name", e.target.value)}
          />
        </div>
        <div className="row-4">
          {[
            ["calories", "Cal"],
            ["protein", "Protein"],
            ["carbs", "Carbs"],
            ["fat", "Fat"],
          ].map(([k, lbl]) => (
            <div className="field" key={k} style={{ marginBottom: 0 }}>
              <label>{lbl}</label>
              <input
                className="input"
                type="number"
                inputMode="numeric"
                placeholder="0"
                value={form[k]}
                onChange={(e) => set(k, e.target.value)}
              />
            </div>
          ))}
        </div>
        <button className="btn amber block" type="submit" style={{ marginTop: 16 }}>
          Add food
        </button>
      </form>
    </Card>
  );
}
