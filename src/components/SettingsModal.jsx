import { useState } from "react";
import Modal from "./Modal";

const FIELDS = [
  { key: "calorie_target", label: "Calorie target", suffix: "cal" },
  { key: "protein_target", label: "Protein target", suffix: "g" },
  { key: "carbs_target", label: "Carbs target", suffix: "g" },
  { key: "fat_target", label: "Fat target", suffix: "g" },
  { key: "water_target_oz", label: "Water target", suffix: "oz" },
];

export default function SettingsModal({ settings, onSave, onClose }) {
  const [form, setForm] = useState({
    surgery_date: settings.surgery_date || "",
    calorie_target: settings.calorie_target,
    protein_target: settings.protein_target,
    carbs_target: settings.carbs_target,
    fat_target: settings.fat_target,
    water_target_oz: settings.water_target_oz,
  });

  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  const save = async () => {
    const patch = {
      surgery_date: form.surgery_date || null,
      calorie_target: Number(form.calorie_target) || 0,
      protein_target: Number(form.protein_target) || 0,
      carbs_target: Number(form.carbs_target) || 0,
      fat_target: Number(form.fat_target) || 0,
      water_target_oz: Number(form.water_target_oz) || 0,
    };
    await onSave(patch);
    onClose();
  };

  return (
    <Modal title="Settings" onClose={onClose}>
      <div className="field">
        <label>Surgery date</label>
        <input
          type="date"
          className="input"
          value={form.surgery_date || ""}
          onChange={(e) => set("surgery_date", e.target.value)}
        />
      </div>

      <div className="section-label">Daily targets</div>
      {FIELDS.map((f) => (
        <div className="field" key={f.key}>
          <label>
            {f.label} ({f.suffix})
          </label>
          <input
            type="number"
            inputMode="numeric"
            className="input"
            value={form[f.key]}
            onChange={(e) => set(f.key, e.target.value)}
          />
        </div>
      ))}

      <button className="btn amber block" onClick={save} style={{ marginTop: 6 }}>
        Save settings
      </button>
    </Modal>
  );
}
