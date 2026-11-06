-- Galería de fotografías para productos ZIVRA / VVS
-- Ejecutar UNA SOLA VEZ en Supabase > SQL Editor.
-- Crea bucket público para que la tienda pueda mostrar las imágenes.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('product-images', 'product-images', true, 10485760, array['image/jpeg','image/png','image/webp','image/avif'])
on conflict (id) do update set public = true, file_size_limit = 10485760,
  allowed_mime_types = array['image/jpeg','image/png','image/webp','image/avif'];

create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  image_url text not null,
  storage_path text,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
alter table public.product_images enable row level security;

drop policy if exists "Public can view product images" on public.product_images;
create policy "Public can view product images" on public.product_images
for select to anon, authenticated using (
  exists (select 1 from public.products p where p.id = product_id and p.active = true)
);
drop policy if exists "Admins manage product images" on public.product_images;
create policy "Admins manage product images" on public.product_images
for all to authenticated using (true) with check (true);

drop policy if exists "Public read product images storage" on storage.objects;
create policy "Public read product images storage" on storage.objects
for select to public using (bucket_id = 'product-images');
drop policy if exists "Authenticated upload product images storage" on storage.objects;
create policy "Authenticated upload product images storage" on storage.objects
for insert to authenticated with check (bucket_id = 'product-images');
drop policy if exists "Authenticated update product images storage" on storage.objects;
create policy "Authenticated update product images storage" on storage.objects
for update to authenticated using (bucket_id = 'product-images') with check (bucket_id = 'product-images');
drop policy if exists "Authenticated delete product images storage" on storage.objects;
create policy "Authenticated delete product images storage" on storage.objects
for delete to authenticated using (bucket_id = 'product-images');

-- Migra la fotografía principal actual a la nueva galería (sin duplicar).
insert into public.product_images(product_id, image_url, sort_order)
select id, image_url, 0 from public.products
where image_url is not null and btrim(image_url) <> ''
and not exists (select 1 from public.product_images pi where pi.product_id = products.id);
