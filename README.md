# Achilles Recovery + Nutrition Tracker

A mobile-first recovery dashboard for tracking nutrition, hydration, and rehab
progress after Achilles surgery. Built with **React + Vite**, **Supabase** for
cross-device sync, and **Recharts** for trends.

Dark charcoal theme · amber nutrition accents · teal recovery/water accents ·
rounded cards · iOS-style bottom navigation.

> Single-user personal app. Bring your own free Supabase project (steps below) and
> it runs at $0. No data or credentials are bundled in this repo.

## Features

Four tabs, optimized for daily phone use:

- **Today** — Day-N-post-op header, live macro rings/bars (calories, protein,
  carbs, fat), a planned-meal checklist, water tracker (+8 oz / reset), a collagen
  toggle, and recovery status chips.
- **Log** — fast food logging with 12 quick-add presets, a custom-food form, a
  per-item delete, and a running daily total.
- **Progress** — bi-weekly check-ins (weight, waist, and 1–5 sliders for energy,
  PT recovery, hunger, sleep, swelling), weight/waist line charts, an
  auto-adjustment hint engine, and a check-in history.
- **Plan** — read-only reference cards: macro targets, recovery supplement stack,
  return-to-sport nutrition ramp, Sunday batch-prep checklist, budget staples, and
  daily success rules.

## Quick start

You need [Node.js](https://nodejs.org) 18+.

```bash
git clone https://github.com/crofton3/recovery-app.git
cd recovery-app
npm install
cp .env.example .env.local   # then fill in your Supabase values (next section)
npm run dev
```

Open the printed URL on your computer, or the **Network** URL on your phone (same
Wi-Fi). On iPhone Safari: Share → *Add to Home Screen* for a full-screen app icon.

## Connect your Supabase project

1. Create a free project at [supabase.com](https://supabase.com) → **New project**.
2. In the dashboard, open **SQL Editor → New query**, paste the contents of
   [`supabase_schema.sql`](./supabase_schema.sql), and **Run**. This creates the
   four tables (`user_settings`, `daily_logs`, `daily_status`, `checkins`),
   enables Row Level Security, and adds the access policies.
3. Open **Project Settings → Data API** to copy your **Project URL**, and
   **Project Settings → API Keys** to copy your **anon / public** key.
4. Put both in `.env.local`:

   ```
   VITE_SUPABASE_URL=https://YOUR-PROJECT-REF.supabase.co
   VITE_SUPABASE_ANON_KEY=your-anon-public-key
   ```

5. Restart `npm run dev`.

`.env.local` is git-ignored, so your keys never get committed.

## Deploy (free)

Build is a static site (`npm run build` → `/dist`). Host it on **Vercel** or
**Netlify**:

1. Import this repo (Vercel) or connect it (Netlify). Build command `npm run build`,
   output directory `dist`.
2. Add the two environment variables `VITE_SUPABASE_URL` and
   `VITE_SUPABASE_ANON_KEY` in the host's project settings.
3. Deploy, then open the URL on your phone → Add to Home Screen.

Because state lives in Supabase, every device you open it on shows the same data.

## Security notes

This is a single-user app with **no login**. The included RLS policies grant the
`anon` role full read/write access — fine for personal use, but it means anyone who
obtains your project URL + anon key (which is shipped in any deployed client build)
could access the data. If you plan to deploy publicly or store anything sensitive,
add Supabase Auth: enable email auth, add a `user_id` column to each table, and
replace the permissive policies with `auth.uid()`-scoped ones. The data layer is
isolated in `src/hooks/useAppData.js`, so this is a contained change.

## Project structure

```
src/
  App.jsx                 # tab router + loading / not-connected states
  index.css               # full dark theme (CSS variables)
  lib/        supabase.js · date.js (local YYYY-MM-DD) · constants.js
  hooks/      useAppData.js          # all data loading + mutations
  context/    ToastContext.jsx       # success / error toasts
  components/  AppShell, BottomNav, Card, ProgressBar, ProgressRing, Modal, SettingsModal
    today/    MacroDashboard, MealTimeline, CollagenToggle, WaterTracker, RecoveryChips
    log/      FoodQuickAdd, CustomFoodForm, LoggedFoodList
    progress/ CheckinForm, ProgressCharts, AdjustmentHint, PastCheckins
    plan/     PlanCard
  tabs/       TodayTab, LogTab, ProgressTab, PlanTab
```

## Notes on behavior

- Dates are **local**, stored as `YYYY-MM-DD` — your "today" never shifts due to UTC.
- Today's `daily_status` row is auto-created on first load.
- Macro totals update instantly; water, collagen, and meal checks save optimistically.
- The meal timeline is a **planned-meal checklist**, not the calorie log — real
  macros come from foods logged on the Log tab.
- The Sunday batch-prep checklist persists locally on the device.
- Adjustment hints are derived from your last two check-ins.

## License

MIT — personal project, use freely.
