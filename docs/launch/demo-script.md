# 40-second LinkedIn demo script

Goal: show one person's whole recovery in one app, then say why it exists. Record in the iOS Simulator with demo mode (fake data only), dark mode, system audio off, captions or voice-over.

**Setup:** `scripts/capture-launch-media.sh video` builds the app, opens the Simulator on Today with a clean 9:41 status bar, and starts recording. Drive the app by hand, then press Enter to stop. It saves `launch-media/video/raw.mov` and, with ffmpeg, a 1080×1920 MP4.

Demo data: left Achilles, surgery about 10 weeks ago, rehab phase 3, today's lower-body session already in progress.

| Time | On screen | Caption (or say) |
|---|---|---|
| 0–4 s | Today: the rings fill | "I tore my Achilles. So I built the app I wanted for recovery." |
| 4–10 s | Scroll Today: water, protein, pain and swelling check | "WHOOP recovery, strain and sleep, plus food, water and a daily pain check, on one screen." |
| 10–18 s | Train tab: tap a set to mark it done; the PR badge shows | "Every set remembers last time, and PRs light up." |
| 18–28 s | Achilles tab: phase, milestone checklist, scroll to pain and swelling trend, left vs right strength | "Rehab phase, milestones, and left-versus-right strength, so I can see the gap closing." |
| 28–34 s | Trends tab: WHOOP charts, recovery on training days | "And whether training is actually helping recovery." |
| 34–40 s | Back to Today, hold on the rings | "Free, open source, no accounts, no ads. SwiftUI + Supabase + the WHOOP API. Link below." |

**Tips**
- Do one silent dry run first; the Simulator is smooth on the second pass.
- Slow, deliberate scrolls read better on a phone feed than fast ones.
- Keep it under 45 s. LinkedIn autoplays muted, so captions carry the story.
- Every number on screen is fake. Never record with your real Supabase project, and never show your project URL.

**Post text (draft, edit in your own voice):**
> After Achilles surgery I was tracking rehab in one app, lifting in another, food in a third, and checking WHOOP in a fourth. None of them talked to each other, and most wanted a subscription.
>
> So I built Achilles: a free iPhone app that puts my rehab phase and milestones, pain and swelling, left-vs-right strength, training log, nutrition and WHOOP recovery in one place.
>
> Built with SwiftUI and Swift Charts, Supabase (Postgres, edge functions, pg_cron for a twice-daily WHOOP sync) and the WHOOP API. CI runs iOS unit tests, SwiftLint, database migration tests and CodeQL on every PR.
>
> It's open source and runs on fake data in demo mode, so anyone can try it. Not medical advice: follow your surgeon and PT.
>
> Repo in the comments. #iosdev #swiftui #supabase #buildinpublic

Put the GitHub link in the first comment, not the post (LinkedIn shows link posts less).
