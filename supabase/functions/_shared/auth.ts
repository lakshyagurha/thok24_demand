// Identity helpers.
//
// The single most important change from the PHP backend: the caller's identity comes
// from a verified JWT, never from a user_id in the request body. Every old endpoint
// trusted `$_POST['user_id']`, which is what let any client read any other user's data.

import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

export type Caller = { id: string; client: SupabaseClient };

/**
 * Resolves the caller from the Authorization header and returns a Supabase client that
 * acts *as that user*, so RLS still applies to everything the function does.
 *
 * Prefer this over the service-role client. Reach for serviceClient() only where the
 * operation legitimately has to bypass RLS (writing orders, admin catalog writes), and
 * even then only after establishing who the caller is.
 */
export async function requireUser(req: Request): Promise<Caller | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) return null;

  const client = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  // getUser() validates the JWT against the auth server rather than trusting its claims.
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) return null;

  return { id: data.user.id, client };
}

/** Bypasses RLS. Never expose this client's key or results to a caller unchecked. */
export function serviceClient(): SupabaseClient {
  return createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });
}

/**
 * True only if the caller is in private.admin_users. That table lives in an unexposed
 * schema and is deliberately not readable by any client, so this check must run through
 * the service-role client.
 *
 * Staff status is NOT taken from JWT claims: user_metadata is user-editable, and
 * app_metadata claims go stale until the token is refreshed.
 */
export async function isAdmin(userId: string): Promise<boolean> {
  const { data, error } = await serviceClient()
    .schema("private")
    .from("admin_users")
    .select("id")
    .eq("id", userId)
    .maybeSingle();
  return !error && !!data;
}
