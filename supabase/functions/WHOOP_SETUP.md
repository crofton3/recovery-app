# WHOOP setup (one time)

The functions `whoop-auth` and `whoop-sync` are deployed to project `pvnpwnphmmkfcivpftbm`. They need a WHOOP developer app and two secrets.

1. Go to https://developer-dashboard.whoop.com and create an app.
2. Scopes: `read:recovery`, `read:cycles`, `read:sleep`, `read:profile`, `offline`.
3. Redirect URI (exactly):
   `https://pvnpwnphmmkfcivpftbm.supabase.co/functions/v1/whoop-auth/callback`
4. Keep the app in its default test mode and add your own WHOOP account as a test user. This is what stops anyone else from linking their WHOOP to your database.
5. In the Supabase dashboard open Edge Functions, then Secrets, and add:
   - `WHOOP_CLIENT_ID`
   - `WHOOP_CLIENT_SECRET`
6. Open the app, go to Today, and tap Connect WHOOP. Sign in, approve, and the app syncs your last 30 days.

Notes:
- Tokens live in `whoop_tokens`, which only the server can read. The app never sees them.
- WHOOP rotates the refresh token on every refresh. `whoop-sync` saves the new one each time.
- The Sync now button pulls 14 days. The app also syncs the last 3 days each time it opens.
