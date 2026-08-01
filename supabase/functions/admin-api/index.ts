// Admin data path for the dxmart_admin Flutter app.
//
// Replaces admin_login.php (which compared passwords in plaintext and was SQL-injectable
// on the email field) and the catalog/order write endpoints.
//
// Design, per the agreed model: the admin app bypasses RLS via the service-role key, but
// only *behind* this function. The key never reaches the client. Staff status is checked
// against private.admin_users -- an unexposed table -- rather than a JWT claim, because
// user_metadata is user-editable and app_metadata goes stale until token refresh.
//
// Catalog tables have no write policy for any client role, so this is the only write path.

import { json, preflight } from "../_shared/cors.ts";
import { isAdmin, requireUser, serviceClient } from "../_shared/auth.ts";

// Only these tables are reachable, so a bug here cannot be steered at auth.users or
// private.admin_users.
const WRITABLE = new Set([
  "products",
  "product_variants",
  "product_images",
  "product_info",
  "product_highlights",
  "product_aliases",
  "main_category",
  "banner",
  "coupon",
  "city",
  "district",
  "app_settings",
  "delivery_boy",
]);
const READABLE = new Set([
  ...WRITABLE,
  "orders",
  "order_items",
  "user_profiles",
  "delivery_address",
  // Read-only view. Backs the category tree screen's warning badges (empty shelves,
  // missing icons, naming-rule violations) without the client re-deriving any of it.
  "v_category_health",
]);

type Body = {
  action:
    | "list"
    | "insert"
    | "update"
    | "delete"
    | "reorder"
    | "order_status"
    | "set_setting"
    | "set_user_status"
    | "upload_image";
  table?: string;
  id?: number | string;
  values?: Record<string, unknown>;
  filters?: Record<string, unknown>;
  limit?: number;
  offset?: number;
  /** `reorder` only: the new sort_order for each category, in one call. */
  order?: { id: number; sort_order: number }[];
  order_id?: number;
  status?: string;
  key?: string;
  value?: string;
};

const ORDER_STATUSES = new Set([
  "pending",
  "packed",
  "way",
  "delivered",
  "cancelled",
]);

Deno.serve(async (req) => {
  const pre = preflight(req);
  if (pre) return pre;

  const caller = await requireUser(req);
  if (!caller) {
    return json({ success: false, message: "Unauthorized" }, 401, req);
  }

  if (!(await isAdmin(caller.id))) {
    // Deliberately identical shape to the 401 above: a non-staff caller learns nothing
    // about whether this endpoint exists or who is staff.
    return json({ success: false, message: "Forbidden" }, 403, req);
  }

  let body: Body;
  try {
    body = await req.json();
  } catch {
    return json({ success: false, message: "Invalid JSON body" }, 400, req);
  }

  const admin = serviceClient();

  try {
    switch (body.action) {
      case "list": {
        const table = String(body.table ?? "");
        if (!READABLE.has(table)) {
          return json({ success: false, message: "Unknown table" }, 400, req);
        }

        let q = admin.from(table).select("*").range(
          body.offset ?? 0,
          (body.offset ?? 0) + Math.min(body.limit ?? 100, 500) - 1,
        );
        for (const [k, v] of Object.entries(body.filters ?? {})) {
          q = q.eq(k, v as never);
        }

        const { data, error } = await q;
        if (error) throw error;
        return json({ success: true, data }, 200, req);
      }

      case "insert": {
        const table = String(body.table ?? "");
        if (!WRITABLE.has(table)) {
          return json({ success: false, message: "Unknown table" }, 400, req);
        }
        const { data, error } = await admin.from(table).insert(
          body.values ?? {},
        ).select().single();
        if (error) throw error;
        return json({ success: true, data }, 200, req);
      }

      case "update": {
        const table = String(body.table ?? "");
        if (!WRITABLE.has(table)) {
          return json({ success: false, message: "Unknown table" }, 400, req);
        }
        if (body.id == null) {
          return json({ success: false, message: "id required" }, 400, req);
        }
        const { data, error } = await admin
          .from(table).update(body.values ?? {}).eq("id", body.id).select()
          .single();
        if (error) throw error;
        return json({ success: true, data }, 200, req);
      }

      case "delete": {
        const table = String(body.table ?? "");
        if (!WRITABLE.has(table)) {
          return json({ success: false, message: "Unknown table" }, 400, req);
        }
        if (body.id == null) {
          return json({ success: false, message: "id required" }, 400, req);
        }
        const { error } = await admin.from(table).delete().eq("id", body.id);
        if (error) throw error;
        return json({ success: true }, 200, req);
      }

      case "reorder": {
        // Drag-to-reorder in the category tree screen. Without this, moving one shelf
        // up rewrites sort_order on every sibling below it, which as individual update
        // calls is N round trips and leaves the tree visibly half-ordered if one fails.
        //
        // Deliberately narrower than `update`: it writes exactly one integer column on
        // one table, so it cannot be steered into editing prices or names.
        if (!Array.isArray(body.order) || body.order.length === 0) {
          return json(
            { success: false, message: "order must be a non-empty array" },
            400,
            req,
          );
        }
        if (body.order.length > 200) {
          return json({ success: false, message: "order too large" }, 400, req);
        }

        const rows: { id: number; sort_order: number }[] = [];
        for (const entry of body.order) {
          const id = Number(entry?.id);
          const sortOrder = Number(entry?.sort_order);
          if (!Number.isInteger(id) || !Number.isInteger(sortOrder)) {
            return json(
              { success: false, message: "each entry needs integer id and sort_order" },
              400,
              req,
            );
          }
          rows.push({ id, sort_order: sortOrder });
        }

        // Sequential rather than a single upsert: an upsert would need every NOT NULL
        // column in the payload, and sending `name` back through a reorder call is how
        // a reorder quietly becomes a rename.
        for (const row of rows) {
          const { error } = await admin
            .from("main_category")
            .update({ sort_order: row.sort_order })
            .eq("id", row.id);
          if (error) throw error;
        }
        return json({ success: true, data: { updated: rows.length } }, 200, req);
      }

      case "order_status": {
        // Orders are otherwise immutable. Status is the one field ops may move, and only
        // to a known value -- no arbitrary column writes on financial records.
        const status = String(body.status ?? "");
        if (!ORDER_STATUSES.has(status)) {
          return json(
            { success: false, message: "Invalid order status" },
            400,
            req,
          );
        }
        if (body.order_id == null) {
          return json(
            { success: false, message: "order_id required" },
            400,
            req,
          );
        }
        const { data, error } = await admin
          .from("orders").update({ status }).eq("id", body.order_id).select(
            "id, status",
          ).single();
        if (error) throw error;
        return json({ success: true, data }, 200, req);
      }

      case "upload_image": {
        // The bucket has no client write policy on purpose: a signed-in customer must
        // not be able to push files into the store's image bucket. Uploads therefore
        // come through here, where staff membership has already been checked.
        //
        // Returns the stored PATH, not a URL. Rows store the path and the host is
        // applied at render time -- baking a host into the row is what left `localhost`
        // and `192.168.31.10` in the old data.
        const b64 = String(body.value ?? "");
        if (!b64) {
          return json(
            { success: false, message: "value (base64) required" },
            400,
            req,
          );
        }

        const contentType = String(body.status ?? "image/jpeg");
        if (!["image/jpeg", "image/png", "image/webp"].includes(contentType)) {
          return json(
            { success: false, message: "Unsupported image type" },
            400,
            req,
          );
        }

        let bytes: Uint8Array;
        try {
          bytes = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
        } catch {
          return json(
            { success: false, message: "Invalid base64 image" },
            400,
            req,
          );
        }
        if (bytes.byteLength > 5 * 1024 * 1024) {
          return json(
            { success: false, message: "Image exceeds 5 MB" },
            400,
            req,
          );
        }

        // Server-generated name: a client-supplied filename could contain path
        // traversal or collide with an existing object.
        const ext = contentType === "image/png"
          ? "png"
          : contentType === "image/webp"
          ? "webp"
          : "jpg";
        const path = `uploads/${crypto.randomUUID()}.${ext}`;

        const { error } = await admin.storage
          .from("product-images")
          .upload(path, bytes, { contentType, upsert: false });
        if (error) throw error;

        return json({ success: true, data: { path } }, 200, req);
      }

      case "set_user_status": {
        // user_profiles is deliberately NOT in WRITABLE: ops should not be able to
        // rewrite arbitrary columns on a customer's profile. Blocking an account is a
        // real need though, so it gets a narrow action with a fixed value set --
        // the same shape as order_status.
        const status = String(body.status ?? "");
        if (status !== "active" && status !== "blocked") {
          return json(
            { success: false, message: "Status must be active or blocked" },
            400,
            req,
          );
        }
        if (!body.id) {
          return json({ success: false, message: "id required" }, 400, req);
        }
        const { data, error } = await admin
          .from("user_profiles")
          .update({ status })
          .eq("id", body.id)
          .select("id, status")
          .single();
        if (error) throw error;
        return json({ success: true, data }, 200, req);
      }

      case "set_setting": {
        // app_settings is keyed by `key` (text) and has no `id` column, so the generic
        // update action above cannot address it -- it matches on id and would 500.
        // Upsert by key instead, which also covers first-time writes for a setting
        // that has never been stored.
        const key = String(body.key ?? "").trim();
        if (!key) {
          return json({ success: false, message: "key required" }, 400, req);
        }
        const { data, error } = await admin
          .from("app_settings")
          .upsert(
            {
              key,
              value: String(body.value ?? ""),
              updated_at: new Date().toISOString(),
            },
            { onConflict: "key" },
          )
          .select()
          .single();
        if (error) throw error;
        return json({ success: true, data }, 200, req);
      }

      default:
        return json({ success: false, message: "Unknown action" }, 400, req);
    }
  } catch (e) {
    console.error("admin-api failed:", e instanceof Error ? e.message : e);
    return json({ success: false, message: "Request failed" }, 500, req);
  }
});
