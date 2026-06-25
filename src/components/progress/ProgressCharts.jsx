import Card from "../Card";
import { formatShort } from "../../lib/date";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  ResponsiveContainer,
  CartesianGrid,
} from "recharts";

function MiniChart({ data, dataKey, color, label, unit }) {
  const points = data
    .filter((d) => d[dataKey] != null)
    .map((d) => ({ date: formatShort(d.date), value: Number(d[dataKey]) }));

  if (points.length < 2) {
    return (
      <div>
        <div className="chart-cap">{label}</div>
        <div className="empty" style={{ padding: "14px 0" }}>
          Need 2+ check-ins to chart {label.toLowerCase()}.
        </div>
      </div>
    );
  }

  return (
    <div className="chart-box">
      <div className="chart-cap">{label}</div>
      <ResponsiveContainer width="100%" height={170}>
        <LineChart data={points} margin={{ top: 6, right: 8, bottom: 0, left: -18 }}>
          <CartesianGrid stroke="rgba(255,255,255,0.05)" vertical={false} />
          <XAxis
            dataKey="date"
            tick={{ fill: "var(--text-faint)", fontSize: 11 }}
            axisLine={false}
            tickLine={false}
          />
          <YAxis
            domain={["auto", "auto"]}
            tick={{ fill: "var(--text-faint)", fontSize: 11 }}
            axisLine={false}
            tickLine={false}
            width={42}
          />
          <Tooltip
            contentStyle={{
              background: "#1d1d20",
              border: "1px solid rgba(255,255,255,0.12)",
              borderRadius: 12,
              fontSize: 13,
              color: "#f5f5f4",
            }}
            labelStyle={{ color: "#8a8a93" }}
            formatter={(v) => [`${v}${unit}`, label]}
          />
          <Line
            type="monotone"
            dataKey="value"
            stroke={color}
            strokeWidth={3}
            dot={{ r: 4, fill: color, strokeWidth: 0 }}
            activeDot={{ r: 6 }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}

export default function ProgressCharts({ checkins }) {
  // Charts read oldest -> newest
  const ordered = [...checkins].reverse();
  return (
    <Card title="Trends">
      <MiniChart
        data={ordered}
        dataKey="body_weight"
        color="var(--amber)"
        label="Body weight"
        unit=" lb"
      />
      <div style={{ height: 8 }} />
      <MiniChart
        data={ordered}
        dataKey="waist"
        color="var(--teal)"
        label="Waist"
        unit=" in"
      />
    </Card>
  );
}
