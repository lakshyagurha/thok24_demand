// The small amount of the customer the agent is allowed to know.
//
// Moved out of the old voice-relay unchanged. It reads through the *caller's*
// RLS client, so it can only ever see that user's own rows, and each read is
// best-effort: losing a greeting detail must never cost someone their session.

import { SupabaseClient } from "jsr:@supabase/supabase-js@2";

export type Profile = {
  name: string | null;
  regulars: string[];
  hasAddress: boolean;
  cartCount: number;
};

export async function buildProfile(
  db: SupabaseClient,
  displayName: string | null,
): Promise<Profile> {
  const profile: Profile = {
    name: displayName,
    regulars: [],
    hasAddress: false,
    cartCount: 0,
  };

  const [regulars, addresses, cart] = await Promise.allSettled([
    db.from("regular_orders")
      .select("products(name)")
      .order("frequency_score", { ascending: false })
      .limit(5),
    db.from("delivery_address").select("id").limit(1),
    db.from("cart_items").select("id"),
  ]);

  if (regulars.status === "fulfilled" && regulars.value.data) {
    profile.regulars = (regulars.value.data as { products?: { name?: string } }[])
      .map((r) => r.products?.name)
      .filter((n): n is string => !!n);
  }
  if (addresses.status === "fulfilled") {
    profile.hasAddress = (addresses.value.data?.length ?? 0) > 0;
  }
  if (cart.status === "fulfilled") {
    profile.cartCount = cart.value.data?.length ?? 0;
  }
  return profile;
}
