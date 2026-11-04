// WHOOP OAuth: /start redirects to WHOOP, /callback exchanges the code and stores tokens.
// Deployed with verify_jwt = false because the browser (not the app) hits these URLs.
// Secrets needed: WHOOP_CLIENT_ID, WHOOP_CLIENT_SECRET. SUPABASE_URL and the service role key are provided automatically.
import { createClient } from "npm:@supabase/supabase-js@2";

const AUTH_URL = "https://api.prod.whoop.com/oauth/oauth2/auth";
const TOKEN_URL = "https://api.prod.whoop.com/oauth/oauth2/token";
const SCOPE = "read:recovery read:cycles read:sleep read:profile offline";
const APP_REDIRECT = "achillesrecovery://whoop";

function randomState(): string {
  // WHOOP requires a state of exactly 8 characters.
  const chars = "abcdefghijklmnopqrstuvwxyz0123456789";
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  return Array.from(bytes, (b) => chars[b % chars.length]).join("");
}

function back(status: string): Response {
  return new Response(null, { status: 302, headers: { Location: `${APP_REDIRECT}/${status}` } });
}

Deno.serve(async (req) => {
  const url = new URL(req.url);
  const action = url.pathname.split("/").filter(Boolean).pop();
  const clientId = Deno.env.get("WHOOP_CLIENT_ID");
  const clientSecret = Deno.env.get("WHOOP_CLIENT_SECRET");
  if (!clientId || !clientSecret) return new Response("WHOOP_CLIENT_ID and WHOOP_CLIENT_SECRET are not set.", { status: 500 });

  const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const redirectUri = `${Deno.env.get("SUPABASE_URL")}/functions/v1/whoop-auth/callback`;

  if (action === "start") {
    const state = randomState();
    const { error } = await db.from("whoop_oauth_state").insert({ state });
    if (error) return new Response(`Could not start sign-in: ${error.message}`, { status: 500 });
    const q = new URLSearchParams({ response_type: "code", client_id: clientId, redirect_uri: redirectUri, scope: SCOPE, state });
    return new Response(null, { status: 302, headers: { Location: `${AUTH_URL}?${q}` } });
  }

  if (action === "callback") {
    const code = url.searchParams.get("code");
    const state = url.searchParams.get("state");
    if (url.searchParams.get("error") || !code || !state) return back("error");

    const since = new Date(Date.now() - 10 * 60 * 1000).toISOString();
    const { data: rows } = await db.from("whoop_oauth_state").delete().eq("state", state).gte("created_at", since).select();
    if (!rows || rows.length === 0) return back("error");

    const res = await fetch(TOKEN_URL, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({ grant_type: "authorization_code", code, client_id: clientId, client_secret: clientSecret, redirect_uri: redirectUri }),
    });
    if (!res.ok) return back("error");
    const t = await res.json();
    if (!t.refresh_token) return back("error");

    const { error } = await db.from("whoop_tokens").upsert({
      id: 1,
      access_token: t.access_token,
      refresh_token: t.refresh_token,
      expires_at: new Date(Date.now() + (t.expires_in ?? 3600) * 1000).toISOString(),
      updated_at: new Date().toISOString(),
    });
    return back(error ? "error" : "connected");
  }

  return new Response("Not found", { status: 404 });
});
