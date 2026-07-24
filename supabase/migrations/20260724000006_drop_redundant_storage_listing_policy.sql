-- The product-images bucket is already marked public at the bucket level (storage.buckets.public
-- = true), so object fetch via a public URL -- client.storage.from(...).getPublicUrl(path), the
-- only storage call either Flutter app makes -- works with zero RLS policy on storage.objects.
--
-- The broad SELECT policy created in 20260724000004_product_images_storage_bucket.sql was
-- therefore pure surplus risk: it enabled storage.objects listing
-- (client.storage.from(...).list()) for anon/authenticated, letting anyone enumerate every
-- filename in the bucket, without adding any capability the app actually uses. Flagged by the
-- Supabase security advisor (public_bucket_allows_listing). Verified via grep that neither
-- dx_mart nor dxmart_admin calls .list()/.move()/.copy() on storage before dropping this.

drop policy if exists "product_images_public_read" on storage.objects;
