import { useState, useEffect } from "react";
import PlanCard from "../components/plan/PlanCard";
import {
  PLAN_MACROS,
  RECOVERY_STACK,
  RTS_PHASES,
  BATCH_PREP,
  BUDGET_STAPLES,
  SUCCESS_RULES,
} from "../lib/constants";

const PREP_KEY = "achilles_batch_prep_v1";

export default function PlanTab() {
  // Batch prep checklist persists locally (simple, no DB needed)
  const [prep, setPrep] = useState({});

  useEffect(() => {
    try {
      const raw = localStorage.getItem(PREP_KEY);
      if (raw) setPrep(JSON.parse(raw));
    } catch (e) {
      /* ignore */
    }
  }, []);

  const toggle = (item) => {
    setPrep((p) => {
      const next = { ...p, [item]: !p[item] };
      try {
        localStorage.setItem(PREP_KEY, JSON.stringify(next));
      } catch (e) {
        /* ignore */
      }
      return next;
    });
  };

  return (
    <div className="tab-scroll">
      <PlanCard title="Macro Targets">
        {PLAN_MACROS.map((m) => (
          <div className="plan-stat" key={m.label}>
            <span className="p-label">{m.label}</span>
            <span className="p-val amber">
              {m.value}
              <span style={{ color: "var(--text-faint)", fontWeight: 600, fontSize: 13 }}>
                {m.unit}
              </span>
            </span>
          </div>
        ))}
        <p className="reason">
          Small deficit during healing to lose fat slowly without hurting recovery.
          High protein preserves muscle and supports tissue repair. Carbs fuel PT,
          gym sessions, and return-to-sport performance.
        </p>
      </PlanCard>

      <PlanCard title="Achilles Recovery Stack">
        {RECOVERY_STACK.map((r) => (
          <div className="plan-stat" key={r.item}>
            <span className="p-label">{r.item}</span>
            <span className="p-val teal">{r.detail}</span>
          </div>
        ))}
      </PlanCard>

      <PlanCard title="Return-to-Sport Nutrition Ramp">
        {RTS_PHASES.map((p) => (
          <div className="phase" key={p.n}>
            <div className="phase-n">{p.n}</div>
            <div>
              <div className="phase-title">{p.title}</div>
              <div className="phase-meta">
                {p.cals} · {p.carbs}
              </div>
            </div>
          </div>
        ))}
      </PlanCard>

      <PlanCard title="Sunday Batch Prep">
        {BATCH_PREP.map((item) => {
          const done = !!prep[item];
          return (
            <div
              className={`checklist-item ${done ? "done" : ""}`}
              key={item}
              onClick={() => toggle(item)}
            >
              <div className={`check ${done ? "on" : ""}`} style={{ width: 24, height: 24 }}>
                ✓
              </div>
              <span className="label">{item}</span>
            </div>
          );
        })}
      </PlanCard>

      <PlanCard title="Budget Staples">
        {BUDGET_STAPLES.map((s) => (
          <div className="bullet" key={s}>
            {s}
          </div>
        ))}
      </PlanCard>

      <PlanCard title="Daily Success Rules">
        {SUCCESS_RULES.map((s) => (
          <div className="bullet" key={s}>
            {s}
          </div>
        ))}
      </PlanCard>
    </div>
  );
}
