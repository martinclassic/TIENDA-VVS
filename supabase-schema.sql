-- Ejecuta este archivo UNA sola vez en Supabase > SQL Editor.
create extension if not exists pgcrypto;
create table if not exists public.products(id uuid primary key default gen_random_uuid(),name text not null,category text not null default 'Selección VVS',description text not null default '',price integer not null default 0 check(price>=0),cost integer not null default 0 check(cost>=0),stock integer not null default 0 check(stock>=0),image_url text,promo_price integer check(promo_price is null or promo_price>=0),promo_label text,featured boolean not null default false,active boolean not null default true,created_at timestamptz not null default now());
create table if not exists public.packs(id uuid primary key default gen_random_uuid(),name text not null,description text not null default '',price integer not null default 0 check(price>=0),original_price integer check(original_price is null or original_price>=0),image_url text,active boolean not null default true,created_at timestamptz not null default now());
create table if not exists public.pack_items(id uuid primary key default gen_random_uuid(),pack_id uuid not null references public.packs(id) on delete cascade,product_id uuid not null references public.products(id) on delete restrict,quantity integer not null default 1 check(quantity>0),unique(pack_id,product_id));

create table if not exists public.store_settings(id integer primary key default 1 check(id=1),topline text not null default 'PIEZAS SELECCIONADAS · CONSULTA DISPONIBILIDAD POR WHATSAPP',hero_title text not null default 'El detalle que cambia todo.',hero_subtitle text not null default 'Joyas para acompañarte todos los días. Una selección pequeña, pensada para quienes prefieren los detalles con carácter.',hero_button text not null default 'Ver colección',hero_image text,contact_text text not null default 'Hablemos de tu próxima pieza.',accent_color text not null default '#c6a56a',background_color text not null default '#f6f4ef',text_color text not null default '#1b1916',updated_at timestamptz not null default now());
insert into public.store_settings(id) values(1) on conflict(id) do nothing;
alter table public.store_settings enable row level security;
drop policy if exists "Public can view store settings" on public.store_settings;
create policy "Public can view store settings" on public.store_settings for select to anon,authenticated using(true);
drop policy if exists "Admins manage store settings" on public.store_settings;
create policy "Admins manage store settings" on public.store_settings for all to authenticated using(true) with check(true);

alter table public.products enable row level security; alter table public.packs enable row level security; alter table public.pack_items enable row level security;
drop policy if exists "Public can view active products" on public.products; create policy "Public can view active products" on public.products for select to anon,authenticated using(active=true);
drop policy if exists "Public can view active packs" on public.packs; create policy "Public can view active packs" on public.packs for select to anon,authenticated using(active=true);
drop policy if exists "Public can view pack items" on public.pack_items; create policy "Public can view pack items" on public.pack_items for select to anon,authenticated using(exists(select 1 from public.packs p where p.id=pack_id and p.active=true));
drop policy if exists "Admins manage products" on public.products; create policy "Admins manage products" on public.products for all to authenticated using(true) with check(true);
drop policy if exists "Admins manage packs" on public.packs; create policy "Admins manage packs" on public.packs for all to authenticated using(true) with check(true);
drop policy if exists "Admins manage pack items" on public.pack_items; create policy "Admins manage pack items" on public.pack_items for all to authenticated using(true) with check(true);
insert into public.products(name,category,description,price,cost,stock,active) values ('Aros Moissanita Cuadrados','Aros','Un diseño limpio y brillante, fácil de combinar.',14990,9000,1,true),('Aros Moissanita Redondos','Aros','Un clásico discreto para usar cualquier día.',13990,8000,1,true);
insert into public.packs(name,description,price,original_price,active) values('Pack Dúo VVS','Lleva ambos diseños en una sola compra.',24990,28980,true);
-- Crea tu usuario desde Authentication > Users y desactiva registros públicos.
-- Estas políticas dan permisos de gestión a usuarios autenticados: protege la creación de usuarios.
