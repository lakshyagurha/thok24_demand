// Shared CORS handling.
//
// The PHP backend sent `Access-Control-Allow-Origin: *` from connection.php on every
// endpoint including admin login. Here the allowed origins are an explicit allowlist
// driven by the ALLOWED_ORIGINS secret (comma-separated).
//
// The Flutter apps are native clients and do not send an Origin header at all, so they
// are unaffected either way; this matters for browser callers and for keeping the admin
// surface from being callable from arbitrary web pages.

const configured = (Deno.env.get("ALLOWED_ORIGINS") ?? "")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);

export function corsHeaders(origin: string | null): Record<string, string> {
  const headers: Record<string, string> = {
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    Vary: "Origin",
  };
  // With no allowlist configured, omit the header entirely rather than defaulting to `*`.
  // Native clients still work; browsers get a clear failure instead of silent wide-open access.
  if (origin && configured.includes(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return headers;
}

export function preflight(req: Request): Response | null {
  if (req.method !== "OPTIONS") return null;
  return new Response("ok", {
    headers: corsHeaders(req.headers.get("Origin")),
  });
}

export function json(
  body: unknown,
  status: number,
  req: Request,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(req.headers.get("Origin")),
      "Content-Type": "application/json",
    },
  });
}
