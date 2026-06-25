import { useState } from "react";
import MacroDashboard from "../components/today/MacroDashboard";
import MealTimeline from "../components/today/MealTimeline";
import CollagenToggle from "../components/today/CollagenToggle";
import WaterTracker from "../components/today/WaterTracker";
import RecoveryChips from "../components/today/RecoveryChips";
import SettingsModal from "../components/SettingsModal";
import { daysBetween, formatNice, todayStr } from "../lib/date";

export default function TodayTab({ data }) {
  const { settings, status, totals } = data;
  const [showSettings, setShowSettings] = useState(false);

  const dayN = settings.surgery_date
    ? daysBetween(settings.surgery_date, todayStr())
    : 0;

  return (
    <div className="tab-scroll">
      <header className="hero">
        <button
          className="gear-btn"
          onClick={() => setShowSettings(true)}
          aria-label="Settings"
        >
          ⚙
        </button>
        <h1 className="hero-day">Day {dayN} Post-Op</h1>
        <p className="hero-sub">{formatNice(todayStr())}</p>
      </header>

      <RecoveryChips totals={totals} status={status} settings={settings} />

      <MacroDashboard totals={totals} settings={settings} />

      <MealTimeline
        checked={status.meals_checked || {}}
        onToggle={data.toggleMeal}
      />

      <WaterTracker
        oz={status.water_oz || 0}
        target={settings.water_target_oz}
        onAdd={(n) => data.setWater((status.water_oz || 0) + n)}
        onReset={() => data.setWater(0)}
      />

      <CollagenToggle taken={status.collagen_taken} onToggle={data.toggleCollagen} />

      {showSettings && (
        <SettingsModal
          settings={settings}
          onSave={data.updateSettings}
          onClose={() => setShowSettings(false)}
        />
      )}
    </div>
  );
}
