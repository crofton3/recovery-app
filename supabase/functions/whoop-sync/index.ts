// Pulls recovery, sleep and strain from WHOOP (API v2) into whoop_daily.
// Called by the app's Sync button and by a daily cron. Deployed with verify_jwt = true.
// Body (optional): { "days": 14 }
import { createClient } from "npm:@supabase/supabase-js@2";

const API = "https://api.prod.whoop.com/developer/v2";
const TOKEN_URL = "https://api.prod.whoop.com/oauth/oauth2/token";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

Deno.serve(async (req) => {
  const clientId = Deno.env.get("WHOOP_CLIENT_ID")?.trim();
  const clientSecret = Deno.env.get("WHOOP_CLIENT_SECRET")?.trim();
  if (!clientId || !clientSecret) return json({ ok: false, error: "WHOOP secrets are not set." }, 500);

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);

  let days = 14;
  try {
    const b = await req.json();
    if (b?.days) days = Math.min(Math.max(Number(b.days), 1), 90);
  } catch { /* no body */ }

  const { data: tok } = await db.from("whoop_tokens").select("*").eq("id", 1).maybeSingle();
  if (!tok) return json({ ok: true, connected: false });

  let access = tok.access_token as string;
  if (new Date(tok.expires_at).getTime() - Date.now() < 5 * 60 * 1000) {
    // Each refresh invalidates the old refresh token, so save the new one immediately.
    const res = await fetch(TOKEN_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "refresh_token",
        refresh_token: tok.refresh_token,
        client_id: clientId,
        client_secret: clientSecret,
        scope: "offline",
      }),
    });
    if (!res.ok) return json({ ok: true, connected: false, reason: "refresh_failed" });
    const t = await res.json();
    access = t.access_token;
    await db.from("whoop_tokens").upsert({
      id: 1,
      access_token: t.access_token,
      refresh_token: t.refresh_token ?? tok.refresh_token,
      expires_at: new Date(Date.now() + (t.expires_in ?? 3600) * 1000).toISOString(),
      updated_at: new Date().toISOString(),
    });
  }

  const start = new Date(Date.now() - days * 86400000).toISOString();

  // deno-lint-ignore no-explicit-any
  async function all(path: string): Promise<any[]> {
    // deno-lint-ignore no-explicit-any
    const out: any[] = [];
    let next: string | undefined;
    do {
      const q = new URLSearchParams({ start, limit: "25" });
      if (next) q.set("nextToken", next);
      const res = await fetch(`${API}${path}?${q}`, { headers: { Authorization: `Bearer ${access}` } });
      if (!res.ok) throw new Error(`WHOOP ${path} returned ${res.status}`);
      const page = await res.json();
      out.push(...(page.records ?? []));
      next = page.next_token || undefined;
    } while (next);
    return out;
  }

  try {
    const [recoveries, cycles, sleeps] = await Promise.all([all("/recovery"), all("/cycle"), all("/activity/sleep")]);

    // Local calendar date of a cycle start, using the cycle's own timezone offset ("-05:00").
    const localDate = (iso: string, offset: string) => {
      const m = /^([+-])(\d{2}):(\d{2})$/.exec(offset ?? "");
      const mins = m ? (m[1] === "-" ? -1 : 1) * (Number(m[2]) * 60 + Number(m[3])) : 0;
      return new Date(Date.parse(iso) + mins * 60000).toISOString().slice(0, 10);
    };

    // deno-lint-ignore no-explicit-any
    const sleepById = new Map<string, any>(
      sleeps.filter((s) => !s.nap && s.score_state === "SCORED").map((s) => [s.id, s]),
    );
    // deno-lint-ignore no-explicit-any
    const recoveryByCycle = new Map<number, any>(
      recoveries.filter((r) => r.score_state === "SCORED").map((r) => [r.cycle_id, r]),
    );

    const perCycle = cycles.map((c) => {
      const r = recoveryByCycle.get(c.id);
      const s = r ? sleepById.get(r.sleep_id) : undefined;
      const ss = s?.score?.stage_summary;
      const asleepMs = ss
        ? (ss.total_light_sleep_time_milli ?? 0) + (ss.total_slow_wave_sleep_time_milli ?? 0) +
          (ss.total_rem_sleep_time_milli ?? 0)
        : null;
      return {
        date: localDate(c.start, c.timezone_offset),
        recovery_score: r?.score?.recovery_score ?? null,
        hrv: r?.score?.hrv_rmssd_milli ?? null,
        rhr: r?.score?.resting_heart_rate ?? null,
        sleep_performance: s?.score?.sleep_performance_percentage ?? null,
        sleep_hours: asleepMs != null ? Math.round((asleepMs / 3600000) * 100) / 100 : null,
        strain: c.score?.strain ?? null,
        kilojoules: c.score?.kilojoule ?? null,
        synced_at: new Date().toISOString(),
      };
    });

    // Two cycles can start on the same local date (short sleeps, travel). Merge them: later values win, but never overwrite with null.
    const byDate = new Map<string, Record<string, unknown>>();
    // WHOOP returns newest first, so reverse to go oldest to newest before merging.
    for (const row of [...perCycle].reverse()) {
      const merged = byDate.get(row.date) ?? {};
      for (const [k, v] of Object.entries(row)) if (v !== null && v !== undefined) merged[k] = v;
      byDate.set(row.date, { date: row.date, ...merged });
    }
    const rows = [...byDate.values()];

    if (rows.length > 0) {
      const { error } = await db.from("whoop_daily").upsert(rows, { onConflict: "date" });
      if (error) return json({ ok: false, error: error.message }, 500);
    }
    return json({ ok: true, connected: true, rows: rows.length });
  } catch (e) {
    return json({ ok: false, error: String(e) }, 502);
  }
});
