// All date helpers use LOCAL time, never UTC, and store as YYYY-MM-DD.

export function todayStr(d = new Date()) {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}

// Parse a YYYY-MM-DD string into a LOCAL Date (avoids UTC shift from new Date(str)).
export function parseLocal(str) {
  if (!str) return null;
  const [y, m, d] = str.split("-").map(Number);
  return new Date(y, m - 1, d);
}

export function daysBetween(aStr, bStr) {
  const a = parseLocal(aStr);
  const b = parseLocal(bStr);
  if (!a || !b) return 0;
  const ms = b.setHours(0, 0, 0, 0) - a.setHours(0, 0, 0, 0);
  return Math.round(ms / 86400000);
}

export function addDays(str, n) {
  const d = parseLocal(str) || new Date();
  d.setDate(d.getDate() + n);
  return todayStr(d);
}

// Default surgery date = 6 weeks ago from today.
export function sixWeeksAgoStr() {
  return addDays(todayStr(), -42);
}

export function formatNice(str) {
  const d = parseLocal(str);
  if (!d) return "";
  return d.toLocaleDateString(undefined, {
    weekday: "long",
    month: "long",
    day: "numeric",
    year: "numeric",
  });
}

export function formatShort(str) {
  const d = parseLocal(str);
  if (!d) return "";
  return d.toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

// 0 = Sunday ... 1 = Monday, 3 = Wednesday
export function weekday(str = todayStr()) {
  const d = parseLocal(str);
  return d ? d.getDay() : new Date().getDay();
}

export function isPtDay(str = todayStr()) {
  const w = weekday(str);
  return w === 1 || w === 3; // Monday or Wednesday
}
