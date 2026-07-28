// Cloudflare Pages Function: reverse-proxy every /api/* request to the Cloud Run
// backend. Because the browser only ever talks to the Pages origin, the session
// cookie the backend sets is first-party (SameSite=Lax), so it survives across
// sessions instead of being dropped as a cross-site cookie.
//
// The backend URL comes from the Pages env var VITE_API_URL, set in the
// Cloudflare dashboard (Settings > Environment variables) -- NOT from any .env
// file in this repo, which Pages Functions never see. Changing it takes effect
// only on the next Pages deployment, which also makes it the rollback switch.
// No path, and any trailing slash trimmed.
export async function onRequest({ request, env }) {
  const origin = (env.VITE_API_URL || "").replace(/\/$/, "");
  if (!origin) {
    return new Response(
      JSON.stringify({ error: "VITE_API_URL is not configured" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  const url = new URL(request.url);
  // strip the leading /api, forward the rest of the path plus the query string
  const target = origin + url.pathname.replace(/^\/api/, "") + url.search;

  // new Request(target, request) carries the method, headers (incl. Cookie) and
  // body over unchanged; returning new Response(body, resp) preserves the status
  // and headers (incl. Set-Cookie) coming back from the backend.
  const resp = await fetch(new Request(target, request));
  return new Response(resp.body, resp);
}
