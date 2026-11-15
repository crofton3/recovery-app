# LinkedIn launch plan

Same shape as the Swing launch: a polished README, a short demo video, a post, and a Projects entry on the profile. Everything shown uses demo mode's fake data.

## Phase 1: Repo ready to be looked at (cloud session)
- [x] `-startTab <tab>` launch argument (demo mode only) so screens can be captured without tapping
- [x] `scripts/capture-launch-media.sh`: builds, boots a dark-mode Simulator with a clean status bar, saves a screenshot of each tab, records the demo video
- [x] Demo script and post draft: [`demo-script.md`](demo-script.md)
- [ ] README: add a "What I learned" section (draft below) and a GIF or video link at the top once recorded
- [ ] Confirm the repo is public and the description, topics (`ios`, `swiftui`, `supabase`, `whoop`, `health`) and social preview image are set

## Phase 2: Capture (on the Mac, through Remote Control)
- [ ] `scripts/capture-launch-media.sh screens` → `launch-media/screens/*.png` at full Retina size
- [ ] Sub-screens by hand with Cmd+S: Train schedule, Achilles PT log and trends, Fuel log, Trends body
- [ ] Replace the 460×1000 images in `docs/public/screenshots/` (resize to 460 wide for the README; keep the full-size ones for LinkedIn)
- [ ] `scripts/capture-launch-media.sh video` and follow the shot list → `launch-media/video/linkedin-1080x1920.mp4`
- [ ] Optional: a real-device screen recording for the hero shot (Control Centre → Screen Recording), demo mode on

## Phase 3: Assets for LinkedIn (cloud session, from the captures)
- [ ] Cover image 1200×627: three phones (Today, Achilles, Trends) on the `#070B14` background with the app name
- [ ] Carousel (PDF, 1080×1350 per page): one page per tab with a one-line caption, last page = stack + repo link
- [ ] Short GIF of the rings filling for the README

## Phase 4: Publish (you)
- [ ] Profile → Add section → **Projects**: name, dates, description (below), skills, media = cover image + video, link = GitHub repo
- [ ] Post: video + text from `demo-script.md`; repo link in the first comment
- [ ] Add the post to **Featured**

## Projects entry (draft)
**Achilles: recovery tracker for iPhone**
A free, open-source SwiftUI app I built after Achilles surgery to track rehab phase and milestones, pain and swelling, left-vs-right strength, training, nutrition and WHOOP recovery in one place. Supabase backend with edge functions for WHOOP OAuth and a twice-daily pg_cron sync; CI with iOS unit tests, SwiftLint, migration tests and CodeQL.
Skills: Swift · SwiftUI · Swift Charts · Supabase · PostgreSQL · REST APIs · GitHub Actions

## "What I learned" (README draft, rewrite in your words)
- **A demo mode pays for itself.** An in-memory stand-in for the database gave me fake-data screenshots, a safe public demo, and fast unit tests, all from one piece of code.
- **Generate the Xcode project.** XcodeGen's `project.yml` means no merge conflicts in `.pbxproj` and a CI build that matches my machine.
- **Sync on the server, not the phone.** WHOOP data arrives through an edge function on a pg_cron schedule, so the app opens to fresh numbers without background refresh.
- **One colour per metric.** A small design system (DESIGN.md) made five tabs feel like one app.

## Remote Control: how this session reaches the Mac
iOS screenshots and video need Xcode, which only runs on the Mac. On the Mac, open the Claude desktop app → Settings → Claude Code → Remote Control and share the `recovery-app` folder (or run `claude remote-control` from that folder). Then the cloud session can run Phase 2 there.
