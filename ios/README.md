# Achilles iOS app

SwiftUI app for iOS 17+. Backend is Supabase (tables in `../supabase/migrations`, WHOOP functions in `../supabase/functions`).

## Run it

1. `brew install xcodegen` (once).
2. Copy `AchillesRecovery/Config/Secrets.example.swift.txt` to `AchillesRecovery/Config/Secrets.swift` and fill in your Supabase URL and anon key. That file is gitignored.
3. `xcodegen generate`, then open `AchillesRecovery.xcodeproj`. The project file is generated from `project.yml`, so change settings there, not in Xcode.
4. Pick a simulator or your iPhone and press Run. On a phone, a free Apple ID works but the install expires after 7 days.

`DEVELOPMENT_TEAM` in `project.yml` is the owner's Apple team. Change it if someone else builds it.

## Tabs

- **Today:** WHOOP rings, nutrition and water rings, due-today workout, Achilles pain and swelling check.
- **Train:** session logger with last-time values and PR badges, weekly schedule editor.
- **Achilles:** rehab phase, milestones, pain and swelling chart, motion and strength by side, PT log.
- **Fuel:** food entry, quick add, end-of-day total, daily targets.
- **Trends:** WHOOP recovery, sleep and strain charts, recovery against training, body weight and waist.

## Reminders

Local notifications, rebuilt each time the app opens or your data changes: a workout reminder at each schedule item's time, and an Achilles check nudge at 8 PM. Both skip today once done. No server or paid Apple account needed.

## WHOOP

See `../supabase/functions/WHOOP_SETUP.md`.
