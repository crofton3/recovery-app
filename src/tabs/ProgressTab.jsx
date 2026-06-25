import Card from "../components/Card";
import CheckinForm from "../components/progress/CheckinForm";
import ProgressCharts from "../components/progress/ProgressCharts";
import AdjustmentHint from "../components/progress/AdjustmentHint";
import PastCheckins from "../components/progress/PastCheckins";
import { todayStr, daysBetween, addDays, formatNice } from "../lib/date";

export default function ProgressTab({ data }) {
  const { checkins } = data;
  const last = checkins[0];
  const daysSince = last ? daysBetween(last.date, todayStr()) : null;
  const due = daysSince == null || daysSince >= 14;
  const nextDue = last ? addDays(last.date, 14) : todayStr();

  return (
    <div className="tab-scroll">
      <Card title="Bi-weekly Check-In">
        {due && (
          <div className="banner amber" style={{ marginBottom: 14 }}>
            {last
              ? `Check-in due — ${daysSince} days since your last one.`
              : "Check-in due — log your first one to start tracking."}
          </div>
        )}
        <div className="ci-stats">
          <div className="ci-stat">
            <span>Last check-in</span>
            <b>{last ? formatNice(last.date) : "—"}</b>
          </div>
          <div className="ci-stat">
            <span>Next due</span>
            <b>{formatNice(nextDue)}</b>
          </div>
        </div>
      </Card>

      <AdjustmentHint checkins={checkins} />

      <CheckinForm onSave={data.addCheckin} />

      <ProgressCharts checkins={checkins} />

      <PastCheckins checkins={checkins} onDelete={data.deleteCheckin} />
    </div>
  );
}
