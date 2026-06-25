import { useState } from "react";
import Card from "../Card";
import { CHECKIN_SLIDERS } from "../../lib/constants";

const EMPTY = {
  body_weight: "",
  waist: "",
  energy: 3,
  pt_recovery: 3,
  hunger: 3,
  sleep: 3,
  swelling: 3,
  notes: "",
};

export default function CheckinForm({ onSave }) {
  const [form, setForm] = useState(EMPTY);
  const [saving, setSaving] = useState(false);
  const set = (k, v) => setForm((f) => ({ ...f, [k]: v }));

  const submit = async (e) => {
    e.preventDefault();
    setSaving(true);
    const ok = await onSave({
      body_weight: form.body_weight === "" ? null : Number(form.body_weight),
      waist: form.waist === "" ? null : Number(form.waist),
      energy: form.energy,
      pt_recovery: form.pt_recovery,
      hunger: form.hunger,
      sleep: form.sleep,
      swelling: form.swelling,
      notes: form.notes.trim() || null,
    });
    setSaving(false);
    if (ok) setForm(EMPTY);
  };

  return (
    <Card title="New Check-In">
      <form onSubmit={submit}>
        <div className="row-2">
          <div className="field">
            <label>Body weight (lb)</label>
            <input
              className="input"
              type="number"
              inputMode="decimal"
              step="0.1"
              placeholder="—"
              value={form.body_weight}
              onChange={(e) => set("body_weight", e.target.value)}
            />
          </div>
          <div className="field">
            <label>Waist (in)</label>
            <input
              className="input"
              type="number"
              inputMode="decimal"
              step="0.1"
              placeholder="—"
              value={form.waist}
              onChange={(e) => set("waist", e.target.value)}
            />
          </div>
        </div>

        {CHECKIN_SLIDERS.map((s) => (
          <div className="slider-row" key={s.key}>
            <div className="slider-top">
              <span className="s-label">{s.label}</span>
              <span className="s-val">{form[s.key]}/5</span>
            </div>
            <input
              type="range"
              min="1"
              max="5"
              step="1"
              value={form[s.key]}
              onChange={(e) => set(s.key, Number(e.target.value))}
            />
          </div>
        ))}

        <div className="field">
          <label>Notes</label>
          <textarea
            className="input"
            placeholder="How's the tendon, training, mood…"
            value={form.notes}
            onChange={(e) => set("notes", e.target.value)}
          />
        </div>

        <button className="btn teal block" type="submit" disabled={saving}>
          {saving ? "Saving…" : "Save check-in"}
        </button>
      </form>
    </Card>
  );
}
