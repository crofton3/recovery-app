import { useState } from "react";
import AppShell from "./components/AppShell";
import TodayTab from "./tabs/TodayTab";
import LogTab from "./tabs/LogTab";
import ProgressTab from "./tabs/ProgressTab";
import PlanTab from "./tabs/PlanTab";
import { useAppData } from "./hooks/useAppData";

export default function App() {
  const [tab, setTab] = useState("today");
  const data = useAppData();

  if (data.loading) {
    return (
      <div className="center-load">
        <div>
          <div className="spinner" />
          <div style={{ marginTop: 14 }}>Loading your dashboard…</div>
        </div>
      </div>
    );
  }

  // Friendly state when Supabase env vars are missing / unreachable.
  if (data.connError || !data.settings) {
    return (
      <div className="center-load">
        <div className="card connect-card">
          <h2 className="card-title">Supabase not connected</h2>
          <p style={{ lineHeight: 1.6, color: "var(--text-2)" }}>
            Add your Supabase credentials to a <code>.env.local</code> file in the
            project root, then restart the dev server:
          </p>
          <pre
            style={{
              background: "var(--surface-2)",
              padding: 14,
              borderRadius: 12,
              fontSize: 12,
              overflowX: "auto",
              color: "var(--text-2)",
            }}
          >
{`VITE_SUPABASE_URL=https://your-ref.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key`}
          </pre>
          <button
            className="btn amber block"
            style={{ marginTop: 14 }}
            onClick={data.reload}
          >
            Retry connection
          </button>
        </div>
      </div>
    );
  }

  return (
    <AppShell active={tab} onChange={setTab}>
      {tab === "today" && <TodayTab data={data} />}
      {tab === "log" && <LogTab data={data} />}
      {tab === "progress" && <ProgressTab data={data} />}
      {tab === "plan" && <PlanTab data={data} />}
    </AppShell>
  );
}
