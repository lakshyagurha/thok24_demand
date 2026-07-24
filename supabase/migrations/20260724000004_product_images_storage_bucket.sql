-- Storage for product and banner imagery, replacing the PHP backend's local
-- /uploads folder.
--
-- Public read: the catalog is browsable before sign-in, and these are product photos,
-- not user content.
--
-- No client write policy at all. Uploads go through the admin Edge Function using the
-- service-role key, exactly like catalog table writes -- otherwise any signed-in
-- customer could push files into the store's image bucket.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  5242880,  -- 5 MB; product photos, not originals
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

create policy "product_images_public_read"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'product-images');
