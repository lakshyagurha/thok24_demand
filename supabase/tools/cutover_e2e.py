#!/usr/bin/env python3
"""
Phase 6 cutover verification: end-to-end, over real HTTP, with real signed-in users.

This is deliberately NOT the same thing as supabase/tests/rls_live_verification.sql.
That one proves the RLS policies are correct by impersonating roles inside Postgres.
This one proves the whole stack in front of them is wired correctly too -- PostgREST
grants, JWT verification, and each Edge Function's own authorization -- which a policy
test cannot reach.

It is self-contained: it creates two throwaway users, exercises every user-facing path
including hostile-input cases, then deletes both. Every dependent row cascades via the
FK on auth.users, so nothing survives the run (verified).

Usage:
    SUPABASE_SERVICE_ROLE_KEY='<service_role key>' python3 supabase/tools/cutover_e2e.py

The service-role key is needed only to create and delete the two test users through the
Auth admin API. Every actual assertion runs as an ordinary signed-in user holding a real
JWT, or anonymously -- never with elevated privileges.

Expect "33/33 passed". Any FAIL is a release blocker.
"""
import json
import os
import sys
import urllib.request
import urllib.error

URL = os.environ.get("SUPABASE_URL", "https://asnjjkpjuqsmjqrjojzl.supabase.co")
KEY = os.environ.get(
    "SUPABASE_PUBLISHABLE_KEY", "sb_publishable_4x3520_7eL-CvEz5Y9_LmQ_OfTCs0xf"
)
SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")

EMAIL_A = "cutover-a@thok24test.com"
EMAIL_B = "cutover-b@thok24test.com"
PASS_A = "CutoverTestA!2026"
PASS_B = "CutoverTestB!2026"

if not SERVICE_KEY:
    print("ERROR: set SUPABASE_SERVICE_ROLE_KEY (needed only to create/delete test users).",
          file=sys.stderr)
    raise SystemExit(2)

results = []



def check(n, name, expected, actual, ok):
    results.append((n, name, expected, actual, ok))


def req(method, path, token=None, body=None, extra_headers=None):
    """Returns (status, parsed_body_or_text)."""
    headers = {"apikey": KEY, "Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if extra_headers:
        headers.update(extra_headers)
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(URL + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(r) as resp:
            raw = resp.read().decode()
            try:
                return resp.status, json.loads(raw)
            except json.JSONDecodeError:
                return resp.status, raw
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except json.JSONDecodeError:
            return e.code, raw


def signin(email, password):
    st, b = req("POST", "/auth/v1/token?grant_type=password",
                body={"email": email, "password": password})
    if st == 200 and isinstance(b, dict) and "access_token" in b:
        return b["access_token"], b["user"]["id"]
    return None, f"HTTP {st}: {b}"




def admin_req(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(
        URL + path, data=data, method=method,
        headers={"apikey": SERVICE_KEY, "Authorization": f"Bearer {SERVICE_KEY}",
                 "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(r) as resp:
            txt = resp.read().decode()
            return resp.status, (json.loads(txt) if txt else None)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:300]


def create_user(email, password, name):
    """Idempotent: removes any leftover of this user from a previous run first."""
    delete_user_by_email(email)
    st, b = admin_req("POST", "/auth/v1/admin/users", {
        "email": email, "password": password,
        "email_confirm": True, "user_metadata": {"name": name},
    })
    if st not in (200, 201):
        print(f"could not create {email}: HTTP {st} {b}", file=sys.stderr)
        raise SystemExit(2)
    return b["id"]


def delete_user_by_email(email):
    st, users = admin_req("GET", f"/auth/v1/admin/users?filter={email}")
    if st == 200 and isinstance(users, dict):
        for u in users.get("users", []):
            if u.get("email") == email:
                admin_req("DELETE", f"/auth/v1/admin/users/{u['id']}")


create_user(EMAIL_A, PASS_A, "Cutover A")
create_user(EMAIL_B, PASS_B, "Cutover B")

# --- 1. Real sign-in ---------------------------------------------------------
tokA, uidA = signin(EMAIL_A, PASS_A)
tokB, uidB = signin(EMAIL_B, PASS_B)
check(1, "User A can sign in with password (real JWT issued)", "token", "token" if tokA else str(uidA), bool(tokA))
check(2, "User B can sign in with password (real JWT issued)", "token", "token" if tokB else str(uidB), bool(tokB))
if not (tokA and tokB):
    for r in results:
        print(r)
    raise SystemExit("cannot continue without both sessions")

# --- 2. Catalog reachable to anon and authenticated --------------------------
st, b = req("GET", "/rest/v1/products?select=id,name&limit=5")
check(3, "Anonymous can browse catalog", "200 + rows", f"{st} n={len(b) if isinstance(b, list) else b}",
      st == 200 and isinstance(b, list) and len(b) > 0)

st, b = req("GET", "/rest/v1/products?select=id,name&limit=5", token=tokA)
check(4, "Signed-in user can browse catalog", "200 + rows", f"{st} n={len(b) if isinstance(b, list) else b}",
      st == 200 and isinstance(b, list) and len(b) > 0)

# --- 3. Anonymous must not reach user data -----------------------------------
st, b = req("GET", "/rest/v1/cart_items?select=id")
check(5, "Anonymous cannot read cart_items", "empty or denied",
      f"{st} {b if not isinstance(b, list) else 'n=' + str(len(b))}",
      st in (401, 403) or (isinstance(b, list) and len(b) == 0))

st, b = req("GET", "/rest/v1/orders?select=id")
check(6, "Anonymous cannot read orders", "empty or denied",
      f"{st} {b if not isinstance(b, list) else 'n=' + str(len(b))}",
      st in (401, 403) or (isinstance(b, list) and len(b) == 0))

# --- 4. Pick a real product/variant ------------------------------------------
st, variants = req("GET", "/rest/v1/product_variants?select=id,product_id,selling_price&limit=2&order=id")
v1 = variants[0]
v2 = variants[1]

# --- 5. Cart isolation between two real users --------------------------------
req("DELETE", f"/rest/v1/cart_items?user_id=eq.{uidA}", token=tokA)
req("DELETE", f"/rest/v1/cart_items?user_id=eq.{uidB}", token=tokB)

st, b = req("POST", "/rest/v1/cart_items", token=tokA,
            body={"user_id": uidA, "product_id": v1["product_id"], "variant_id": v1["id"], "quantity": 2})
check(7, "A can add to own cart", "201", str(st), st in (200, 201))

st, b = req("POST", "/rest/v1/cart_items", token=tokB,
            body={"user_id": uidB, "product_id": v2["product_id"], "variant_id": v2["id"], "quantity": 5})
check(8, "B can add to own cart", "201", str(st), st in (200, 201))

st, b = req("GET", "/rest/v1/cart_items?select=id,user_id,quantity", token=tokA)
own = isinstance(b, list) and all(r["user_id"] == uidA for r in b) and len(b) == 1
check(9, "A sees only own cart row over PostgREST", "1 row, all A",
      f"{st} n={len(b) if isinstance(b, list) else b}", own)

# The attack the old PHP backend was vulnerable to: ask for another user's rows by id.
st, b = req("GET", f"/rest/v1/cart_items?select=id,user_id&user_id=eq.{uidB}", token=tokA)
check(10, "A filtering explicitly for B's user_id returns nothing", "0 rows",
      f"{st} n={len(b) if isinstance(b, list) else b}", isinstance(b, list) and len(b) == 0)

# --- 6. Cross-user write attempts --------------------------------------------
st, b = req("POST", "/rest/v1/cart_items", token=tokA,
            body={"user_id": uidB, "product_id": v1["product_id"], "variant_id": v1["id"], "quantity": 9})
check(11, "A cannot insert a cart row owned by B (WITH CHECK)", "4xx", str(st), st >= 400)

st, b = req("PATCH", f"/rest/v1/cart_items?user_id=eq.{uidB}", token=tokA, body={"quantity": 99})
changed = isinstance(b, list) and len(b) > 0
check(12, "A cannot update B's cart rows", "0 rows affected",
      f"{st} affected={len(b) if isinstance(b, list) else b}", st < 400 and not changed)

st, b = req("DELETE", f"/rest/v1/cart_items?user_id=eq.{uidB}", token=tokA,
            extra_headers={"Prefer": "return=representation"})
deleted = isinstance(b, list) and len(b) > 0
check(13, "A cannot delete B's cart rows", "0 rows affected",
      f"{st} affected={len(b) if isinstance(b, list) else b}", st < 400 and not deleted)

# --- 7. Orders are not client-writable ---------------------------------------
st, b = req("POST", "/rest/v1/orders", token=tokA,
            body={"user_id": uidA, "total_amount": 1, "final_amount": 0.01})
check(14, "A cannot INSERT an order directly (self-priced order blocked)", "4xx", str(st), st >= 400)

# --- 8. Rider PII --------------------------------------------------------------
st, b = req("GET", "/rest/v1/delivery_boy?select=id,name,mobile", token=tokA)
check(15, "Rider PII (delivery_boy) unreachable by a normal user", "empty or denied",
      f"{st} {b if not isinstance(b, list) else 'n=' + str(len(b))}",
      st in (401, 403) or (isinstance(b, list) and len(b) == 0))

# --- 9. Address, then a real order through the Edge Function -------------------
st, addr = req("POST", "/rest/v1/delivery_address", token=tokA,
               body={"user_id": uidA, "name": "Cutover A", "phone": "9000000001",
                     "full_address": "1 Test Street, Sagar", "pin_code": "470001"},
               extra_headers={"Prefer": "return=representation"})
addr_id = addr[0]["id"] if isinstance(addr, list) and addr else None
check(16, "A can create own delivery address", "201 + id", f"{st} id={addr_id}", addr_id is not None)

# Recompute expected total from the catalog, independently of the function.
expected_sub = round(float(v1["selling_price"]) * 2, 2)

# Deliberately send hostile money fields. The old PHP took these from the body.
st, order = req("POST", "/functions/v1/place-order", token=tokA, body={
    "delivery_address_id": addr_id,
    "payment_method": "COD",
    "total_amount": 0.01,
    "final_amount": 0.01,
    "discount_amount": 9999,
    "delivery_charge": 0,
    "handling_charge": 0,
})
ok_order = isinstance(order, dict) and order.get("success") is True
check(17, "place-order succeeds for a signed-in user", "success",
      f"{st} {order if not ok_order else 'ok id=' + str(order.get('order_id'))}", ok_order)

if ok_order:
    check(18, "Server recomputed subtotal from catalog, ignoring client's total_amount",
          str(expected_sub), str(order.get("total_amount")),
          abs(float(order["total_amount"]) - expected_sub) < 0.01)
    check(19, "Client's injected discount_amount=9999 was ignored", "0",
          str(order.get("discount_amount")), float(order.get("discount_amount", -1)) == 0)
    check(20, "final_amount is server-computed, not the client's 0.01", "> 0.01",
          str(order.get("final_amount")), float(order.get("final_amount", 0)) > 0.01)
    oid = order["order_id"]

    st, b = req("GET", f"/rest/v1/orders?select=id,final_amount,status&id=eq.{oid}", token=tokA)
    check(21, "A can read own order back", "1 row",
          f"{st} n={len(b) if isinstance(b, list) else b}", isinstance(b, list) and len(b) == 1)

    st, b = req("GET", f"/rest/v1/orders?select=id&id=eq.{oid}", token=tokB)
    check(22, "B cannot see A's order", "0 rows",
          f"{st} n={len(b) if isinstance(b, list) else b}", isinstance(b, list) and len(b) == 0)

    st, b = req("GET", f"/rest/v1/order_items?select=id,order_id&order_id=eq.{oid}", token=tokB)
    check(23, "B cannot see A's order_items", "0 rows",
          f"{st} n={len(b) if isinstance(b, list) else b}", isinstance(b, list) and len(b) == 0)

    st, b = req("GET", "/rest/v1/cart_items?select=id", token=tokA)
    check(24, "A's cart was emptied after checkout", "0 rows",
          f"{st} n={len(b) if isinstance(b, list) else b}", isinstance(b, list) and len(b) == 0)

    st, b = req("GET", "/rest/v1/regular_orders?select=id,frequency_score", token=tokA)
    check(25, "Repeat-order memory recorded for A", ">=1 row",
          f"{st} n={len(b) if isinstance(b, list) else b}", isinstance(b, list) and len(b) >= 1)

    st, b = req("PATCH", f"/rest/v1/orders?id=eq.{oid}", token=tokA, body={"status": "delivered"})
    moved = isinstance(b, list) and len(b) > 0
    check(26, "A cannot change own order status (no UPDATE policy)", "0 rows affected",
          f"{st} affected={len(b) if isinstance(b, list) else b}", st >= 400 or not moved)

# --- 10. Empty cart is refused ------------------------------------------------
st, b = req("POST", "/functions/v1/place-order", token=tokA,
            body={"delivery_address_id": addr_id, "payment_method": "COD"})
check(27, "place-order refuses an empty cart", "success=false",
      f"{st} {b.get('message') if isinstance(b, dict) else b}",
      isinstance(b, dict) and b.get("success") is False)

# --- 11. Edge Function authorization -----------------------------------------
st, b = req("POST", "/functions/v1/place-order", body={"payment_method": "COD"})
check(28, "place-order rejects an unauthenticated caller", "401", str(st), st == 401)

st, b = req("POST", "/functions/v1/admin-api", token=tokA, body={"action": "list", "table": "orders"})
check(29, "admin-api rejects a non-staff signed-in user", "403",
      f"{st} {b.get('message') if isinstance(b, dict) else b}", st == 403)

st, b = req("POST", "/functions/v1/admin-api", body={"action": "list", "table": "orders"})
check(30, "admin-api rejects an unauthenticated caller", "401", str(st), st == 401)

st, b = req("POST", "/functions/v1/send-order-email", token=tokA, body={"order_id": 1})
check(31, "send-order-email rejects a user JWT (service-role only)", "401", str(st), st == 401)

st, b = req("POST", "/functions/v1/razorpay-webhook", body={"event": "payment.captured"})
check(32, "razorpay-webhook rejects an unsigned payload", "4xx",
      f"{st} {b}", st >= 400)

# --- 12. Invalid payment method ----------------------------------------------
st, b = req("POST", "/functions/v1/place-order", token=tokA,
            body={"delivery_address_id": addr_id, "payment_method": "FREE_MONEY"})
check(33, "place-order rejects an unknown payment method", "success=false",
      f"{st} {b.get('message') if isinstance(b, dict) else b}",
      isinstance(b, dict) and b.get("success") is False)

# --- 13. Category tree, as the consumer app actually fetches it ---------------
#
# The whole browsable catalogue in one call, before sign-in. Anonymous on purpose:
# this is the first request the app makes and it must work with no session at all.
st, tree = req("POST", "/rest/v1/rpc/category_tree", body={})
check(34, "Anonymous can fetch the category tree", "200 + 6 umbrellas",
      f"{st} n={len(tree) if isinstance(tree, list) else tree}",
      st == 200 and isinstance(tree, list) and len(tree) == 6)

shelves = [s for u in (tree if isinstance(tree, list) else []) for s in u.get("children", [])]
check(35, "Tree carries all 34 shelves", "34", str(len(shelves)), len(shelves) == 34)

# Retired and staging nodes must never reach a shopper. `Uncategorised` is a work
# queue, not an "Others" shelf, and the two retired categories still hold rows.
hidden = {"uncategorised", "unfiled", "retired-electronics-appliances",
          "retired-packaged-food"}
leaked = [c["slug"] for c in (tree if isinstance(tree, list) else []) + shelves
          if c.get("slug") in hidden]
check(36, "No retired or staging category is exposed", "none",
      str(leaked or "none"), not leaked)

check(37, "No inactive node is exposed", "none",
      str([c["slug"] for c in (tree if isinstance(tree, list) else []) + shelves
           if not c.get("is_active")] or "none"),
      all(c.get("is_active") for c in (tree if isinstance(tree, list) else []) + shelves))

# product_count is what drives the "Coming soon" state, so a wrong count is a
# shopper being sent into an empty aisle -- or a stocked one being hidden.
total = sum(u.get("product_count", 0) for u in (tree if isinstance(tree, list) else []))
check(38, "Subtree counts sum to the active SKU count", "35", str(total), total == 35)

consistent = all(
    u.get("product_count", 0) == sum(c.get("product_count", 0) for c in u.get("children", []))
    for u in (tree if isinstance(tree, list) else [])
)
check(39, "Each umbrella's count equals the sum of its shelves", "consistent",
      "consistent" if consistent else "mismatched", consistent)

# Withdrawn SKUs must be gone from every catalogue read, not just from their shelf.
st, b = req("GET", "/rest/v1/products?select=id&is_active=eq.false")
withdrawn = {r["id"] for r in b} if isinstance(b, list) else set()
st, b = req("GET", "/rest/v1/products?select=id&is_active=eq.true&limit=200")
active = {r["id"] for r in b} if isinstance(b, list) else set()
check(40, "Withdrawn SKUs are excluded from the active catalogue", "no overlap",
      str(sorted(withdrawn & active) or "no overlap"), not (withdrawn & active))

# A product filed on an umbrella would be unreachable in the app: the browse screen
# only ever opens shelves.
st, b = req("GET", "/rest/v1/main_category?select=id&level=eq.1")
umbrella_ids = {r["id"] for r in b} if isinstance(b, list) else set()
st, b = req("GET", "/rest/v1/products?select=id,main_category_id&limit=200")
on_umbrella = [r["id"] for r in b if r.get("main_category_id") in umbrella_ids] \
    if isinstance(b, list) else []
check(41, "No product is filed on an umbrella", "none",
      str(on_umbrella or "none"), not on_umbrella)

# The catalogue must stay writable only through admin-api.
st, b = req("POST", "/rest/v1/main_category", token=tokA,
            body={"name": "ZZ E2E Injected", "slug": "zz-e2e-injected", "level": 1})
check(42, "A signed-in user cannot create a category", "denied", str(st), st in (401, 403))

st, b = req("PATCH", "/rest/v1/main_category?id=eq." + str(shelves[0]["id"]), token=tokA,
            body={"name": "ZZ Renamed"})
renamed = isinstance(b, list) and len(b) > 0
check(43, "A signed-in user cannot rename a category", "denied",
      f"{st}{' ROWS CHANGED' if renamed else ''}",
      st in (401, 403) or not renamed)

# --- teardown: remove both users; all dependent rows cascade ------------------
delete_user_by_email(EMAIL_A)
delete_user_by_email(EMAIL_B)

# --- report -------------------------------------------------------------------
width = max(len(r[1]) for r in results)
passed = 0
for n, name, exp, act, ok in results:
    flag = "PASS" if ok else "*** FAIL ***"
    passed += 1 if ok else 0
    print(f"{n:>3}. {name:<{width}}  exp={exp:<22} got={act:<34} {flag}")
print(f"\n{passed}/{len(results)} passed")
