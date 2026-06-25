import Card from "../Card";
import { formatNice } from "../../lib/date";

const STATS = [
  ["energy", "Energy"],
  ["pt_recovery", "PT recovery"],
  ["hunger", "Hunger"],
  ["sleep", "Sleep"],
  ["swelling", "Swelling"],
];

export default function PastCheckins({ checkins, onDelete }) {
  return (
    <Card title={`Past Check-Ins · ${checkins.length}`}>
      {checkins.length === 0 ? (
        <div className="empty">No check-ins yet. Save your first one above.</div>
      ) : (
        checkins.map((c) => (
          <div className="ci-card" key={c.id}>
            <div className="ci-head">
              <span className="ci-date">{formatNice(c.date)}</span>
              <button className="del" onClick={() => onDelete(c.id)} aria-label="Delete">
                ✕
              </button>
            </div>
            <div className="ci-stats">
              {c.body_weight != null && (
                <div className="ci-stat">
                  <span>Weight</span>
                  <b>{c.body_weight} lb</b>
                </div>
              )}
              {c.waist != null && (
                <div className="ci-stat">
                  <span>Waist</span>
                  <b>{c.waist} in</b>
                </div>
              )}
              {STATS.map(([k, lbl]) =>
                c[k] != null ? (
                  <div className="ci-stat" key={k}>
                    <span>{lbl}</span>
                    <b>{c[k]}/5</b>
                  </div>
                ) : null
              )}
            </div>
            {c.notes && <div className="ci-notes">{c.notes}</div>}
          </div>
        ))
      )}
    </Card>
  );
}
