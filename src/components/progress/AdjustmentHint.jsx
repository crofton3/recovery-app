import Card from "../Card";
import { daysBetween } from "../../lib/date";

// Uses the last two check-ins (checkins are passed newest-first).
function computeHints(checkins) {
  const hints = [];
  if (checkins.length === 0) return hints;

  const latest = checkins[0];

  // Swelling (single latest reading is enough to flag)
  if (latest.swelling != null && latest.swelling >= 4) {
    hints.push({
      type: "warn",
      text: "Watch swelling trends. Nutrition helps, but loading and recovery matter most.",
    });
  }

  // Low energy / PT recovery
  if (
    (latest.energy != null && latest.energy <= 2) ||
    (latest.pt_recovery != null && latest.pt_recovery <= 2)
  ) {
    hints.push({
      type: "teal",
      text: "Consider adding 30–50g carbs around PT/gym.",
    });
  }

  // Weight trend from last two check-ins
  if (checkins.length >= 2) {
    const prev = checkins[1];
    if (latest.body_weight != null && prev.body_weight != null) {
      const days = Math.abs(daysBetween(latest.date, prev.date)) || 14;
      const lostPerWeek = ((prev.body_weight - latest.body_weight) / days) * 7;

      if (lostPerWeek > 1) {
        hints.push({
          type: "amber",
          text: "Add ~150 calories, mostly carbs. Healing first.",
        });
      } else if (Math.abs(lostPerWeek) < 0.001) {
        hints.push({
          type: "amber",
          text: "Cut ~150 calories from fat/carbs, never protein.",
        });
      } else if (lostPerWeek >= 0.25 && lostPerWeek <= 0.75) {
        hints.push({
          type: "teal",
          text: "Hold steady. You're on target.",
        });
      }
    }
  }

  return hints;
}

export default function AdjustmentHint({ checkins }) {
  const hints = computeHints(checkins);
  return (
    <Card title="Adjustment Hints">
      {hints.length === 0 ? (
        <div className="empty">
          Log at least two check-ins to get tailored adjustments.
        </div>
      ) : (
        <div className="hint-list">
          {hints.map((h, i) => (
            <div className={`banner ${h.type}`} key={i}>
              {h.text}
            </div>
          ))}
        </div>
      )}
    </Card>
  );
}
