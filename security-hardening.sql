-- =====================================================================
-- MJ ICED: ENDURECIMIENTO DE SEGURIDAD
-- Ejecutar en Supabase > SQL Editor, DESPUÉS de todos los demás SQL.
-- Es seguro repetirlo.
--
-- IMPORTANTE ANTES DE EJECUTAR:
--   1) Cambia el correo de la línea marcada con  <<< CAMBIA ESTO  por el
--      correo de tu cuenta (la que creaste en Authentication > Users).
--   2) Si el correo no existe, el script se detiene sin cambiar nada
--      y no te quedarás sin acceso.
--
-- Qué corrige:
--   * Hasta ahora CUALQUIER usuario con sesión era administrador. Ahora solo
--     las cuentas de la lista admin_users.
--   * Los visitantes ya no pueden leer el costo de tus productos.
--   * Las funciones de ventas verifican que quien las usa sea administrador y
--     las funciones internas ya no se pueden llamar desde fuera.
--   * Subir/editar/borrar fotos exige ser administrador.
-- =====================================================================

-- 1) Lista de administradores --------------------------------------------
create table if not exists public.admin_users(
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.admin_users enable row level security;
revoke all on public.admin_users from anon, authenticated;

do $$
declare v_email text := 'TU_CORREO@EJEMPLO.COM';   -- <<< CAMBIA ESTO
begin
  insert into public.admin_users(user_id)
    select id from auth.users where lower(email) = lower(v_email)
    on conflict do nothing;
  if not exists (select 1 from public.admin_users) then
    raise exception 'No encontré ese correo en Authentication > Users. Cambia TU_CORREO@EJEMPLO.COM por el tuyo y vuelve a ejecutar.';
  end if;
end $$;

create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path = public, pg_temp
as $$ select exists (select 1 from public.admin_users where user_id = auth.uid()) $$;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- 2) Políticas de las tablas ----------------------------------------------
do $$
declare r record;
begin
  for r in select schemaname, tablename, policyname from pg_policies
           where (schemaname = 'public' and tablename in ('products','packs','pack_items','store_settings','product_images','sales','sale_items','supply_expenses'))
              or (schemaname = 'storage' and tablename = 'objects' and policyname ilike '%product images%')
  loop
    execute format('drop policy %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- Lectura pública (solo lo visible) + gestión solo para administradores
create policy "Public can view active products" on public.products for select to anon using (active = true);
create policy "Admins manage products" on public.products for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "Public can view active packs" on public.packs for select to anon using (active = true);
create policy "Admins manage packs" on public.packs for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "Public can view pack items" on public.pack_items for select to anon
  using (exists (select 1 from public.packs p where p.id = pack_id and p.active = true));
create policy "Admins manage pack items" on public.pack_items for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "Public can view store settings" on public.store_settings for select to anon using (true);
create policy "Admins manage store settings" on public.store_settings for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "Public can view product images" on public.product_images for select to anon
  using (exists (select 1 from public.products p where p.id = product_id and p.active = true));
create policy "Admins manage product images" on public.product_images for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "Admins manage sales" on public.sales for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "Admins manage sale items" on public.sale_items for all to authenticated using (public.is_admin()) with check (public.is_admin());

do $$ begin
  if to_regclass('public.supply_expenses') is not null then
    execute 'create policy "Admins manage supply expenses" on public.supply_expenses for all to authenticated using (public.is_admin()) with check (public.is_admin())';
  end if;
end $$;

-- 3) Permisos de columnas y tablas ------------------------------------------
-- Los visitantes pueden leer los productos visibles, pero NO la columna "cost".
do $$
declare cols text;
begin
  select string_agg(quote_ident(column_name), ',') into cols
    from information_schema.columns
   where table_schema = 'public' and table_name = 'products' and column_name <> 'cost';
  execute 'revoke all on public.products from anon';
  execute format('grant select (%s) on public.products to anon', cols);
end $$;

do $$
declare t text;
begin
  foreach t in array array['packs','pack_items','store_settings','product_images'] loop
    if to_regclass('public.' || t) is not null then
      execute format('revoke insert, update, delete, truncate, references, trigger on public.%I from anon', t);
    end if;
  end loop;
  foreach t in array array['sales','sale_items','supply_expenses'] loop
    if to_regclass('public.' || t) is not null then
      execute format('revoke all on public.%I from anon', t);
    end if;
  end loop;
  foreach t in array array['products','packs','pack_items','store_settings','product_images','sales','sale_items','supply_expenses'] loop
    if to_regclass('public.' || t) is not null then
      execute format('revoke truncate, references, trigger on public.%I from authenticated', t);
    end if;
  end loop;
end $$;

-- 4) Fotos (almacenamiento) ---------------------------------------------------
update storage.buckets
   set public = true, file_size_limit = 10485760,
       allowed_mime_types = array['image/jpeg','image/png','image/webp','image/avif']
 where id = 'product-images';

create policy "Public read product images storage" on storage.objects for select to public using (bucket_id = 'product-images');
create policy "Admins upload product images storage" on storage.objects for insert to authenticated
  with check (bucket_id = 'product-images' and public.is_admin());
create policy "Admins update product images storage" on storage.objects for update to authenticated
  using (bucket_id = 'product-images' and public.is_admin()) with check (bucket_id = 'product-images' and public.is_admin());
create policy "Admins delete product images storage" on storage.objects for delete to authenticated
  using (bucket_id = 'product-images' and public.is_admin());

-- 5) Funciones de ventas: solo administradores ---------------------------------
-- Antes de recrearlas, nadie salvo el propio sistema puede ejecutar funciones de tu proyecto.
do $$
declare f regprocedure;
begin
  for f in select p.oid::regprocedure from pg_proc p
            where p.pronamespace = 'public'::regnamespace
              and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
  loop
    execute format('revoke execute on function %s from public, anon', f);
  end loop;
end $$;
alter default privileges in schema public revoke execute on functions from public, anon;

-- Compatibilidad: columnas de anulación y versiones anteriores de las funciones
alter table public.sales
  add column if not exists status text not null default 'active',
  add column if not exists cancelled_at timestamptz;
drop function if exists public.update_vvs_sale(uuid, text, uuid, integer, text, text, text);
drop function if exists public.cancel_vvs_sale(uuid);
drop function if exists public.register_vvs_sale(text, uuid, integer, text, text, text);
drop function if exists public._vvs_add_sale_item(uuid, text, uuid, integer);
drop function if exists public._vvs_restore_sale_stock(uuid);

create or replace function public._vvs_add_sale_item(
  p_sale_id uuid,
  p_item_type text,
  p_item_id uuid,
  p_quantity integer,
  out o_total integer,
  out o_cost integer
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_name text;
  v_price integer;
  v_unit_cost integer;
  v_stock integer;
  v_product record;
begin
  if p_item_type = 'product' then
    select name,
           case when promo_price is not null and promo_price > 0 and promo_price < price then promo_price else price end,
           cost, stock
      into v_name, v_price, v_unit_cost, v_stock
      from public.products
     where id = p_item_id and active = true
       for update;
    if not found then raise exception 'El producto no existe o está oculto.'; end if;
    if v_stock < p_quantity then raise exception 'Stock insuficiente. Disponible: %', v_stock; end if;

    update public.products set stock = stock - p_quantity where id = p_item_id;
    o_total := v_price * p_quantity;
    o_cost := v_unit_cost * p_quantity;

    insert into public.sale_items(sale_id, product_id, item_name, quantity, unit_price, unit_cost, line_total, line_profit)
    values (p_sale_id, p_item_id, v_name, p_quantity, v_price, v_unit_cost, o_total, o_total - o_cost);

  elsif p_item_type = 'pack' then
    select name, price into v_name, v_price
      from public.packs
     where id = p_item_id and active = true
       for update;
    if not found then raise exception 'El pack no existe o está oculto.'; end if;
    if not exists (select 1 from public.pack_items where pack_id = p_item_id) then
      raise exception 'Este pack no tiene productos asociados.';
    end if;

    o_cost := 0;
    for v_product in
      select pr.id, pr.name, pr.stock, pr.cost, pi.quantity as pack_quantity
        from public.pack_items pi
        join public.products pr on pr.id = pi.product_id
       where pi.pack_id = p_item_id
       order by pr.id
         for update of pr
    loop
      if v_product.stock < v_product.pack_quantity * p_quantity then
        raise exception 'Stock insuficiente para % (disponible: %, requerido: %).',
          v_product.name, v_product.stock, v_product.pack_quantity * p_quantity;
      end if;
      update public.products set stock = stock - (v_product.pack_quantity * p_quantity) where id = v_product.id;
      o_cost := o_cost + (v_product.cost * v_product.pack_quantity * p_quantity);
    end loop;

    o_total := v_price * p_quantity;

    insert into public.sale_items(sale_id, pack_id, item_name, quantity, unit_price, unit_cost, line_total, line_profit)
    values (p_sale_id, p_item_id, v_name, p_quantity, v_price, o_cost / p_quantity, o_total, o_total - o_cost);

  else
    raise exception 'Tipo de artículo no válido.';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Auxiliar: devuelve al inventario las unidades de una venta.
-- ---------------------------------------------------------------------------
create or replace function public._vvs_restore_sale_stock(p_sale_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  i record;
begin
  for i in select product_id, pack_id, quantity from public.sale_items where sale_id = p_sale_id loop
    if i.product_id is not null then
      update public.products set stock = stock + i.quantity where id = i.product_id;
    elsif i.pack_id is not null then
      update public.products pr
         set stock = pr.stock + pi.quantity * i.quantity
        from public.pack_items pi
       where pi.pack_id = i.pack_id and pr.id = pi.product_id;
    end if;
  end loop;
end;
$$;


-- ---------------------------------------------------------------------------
-- Registrar venta (ahora respeta el precio de oferta).
-- ---------------------------------------------------------------------------
create or replace function public.register_vvs_sale(
  p_item_type text,
  p_item_id uuid,
  p_quantity integer,
  p_customer_name text default null,
  p_customer_contact text default null,
  p_notes text default null
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sale_id uuid;
  v_total integer;
  v_cost integer;
begin
  if not public.is_admin() then raise exception 'No tienes permisos de administrador para registrar ventas.'; end if;
  if p_quantity is null or p_quantity < 1 then raise exception 'La cantidad debe ser al menos 1.'; end if;

  insert into public.sales(customer_name, customer_contact, notes)
  values (nullif(trim(p_customer_name), ''), nullif(trim(p_customer_contact), ''), nullif(trim(p_notes), ''))
  returning id into v_sale_id;

  select o_total, o_cost into v_total, v_cost
    from public._vvs_add_sale_item(v_sale_id, p_item_type, p_item_id, p_quantity);

  update public.sales
     set total_amount = v_total, total_cost = v_cost, total_profit = v_total - v_cost
   where id = v_sale_id;

  return v_sale_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Editar venta: devuelve el stock anterior, descuenta el nuevo y recalcula.
-- ---------------------------------------------------------------------------
create or replace function public.update_vvs_sale(
  p_sale_id uuid,
  p_item_type text,
  p_item_id uuid,
  p_quantity integer,
  p_customer_name text default null,
  p_customer_contact text default null,
  p_notes text default null
) returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_status text;
  v_total integer;
  v_cost integer;
begin
  if not public.is_admin() then raise exception 'No tienes permisos de administrador para editar ventas.'; end if;
  if p_quantity is null or p_quantity < 1 then raise exception 'La cantidad debe ser al menos 1.'; end if;

  select status into v_status from public.sales where id = p_sale_id for update;
  if not found then raise exception 'La venta no existe.'; end if;
  if v_status = 'cancelled' then raise exception 'No se puede editar una venta anulada.'; end if;

  perform public._vvs_restore_sale_stock(p_sale_id);
  delete from public.sale_items where sale_id = p_sale_id;

  select o_total, o_cost into v_total, v_cost
    from public._vvs_add_sale_item(p_sale_id, p_item_type, p_item_id, p_quantity);

  update public.sales
     set customer_name = nullif(trim(p_customer_name), ''),
         customer_contact = nullif(trim(p_customer_contact), ''),
         notes = nullif(trim(p_notes), ''),
         total_amount = v_total, total_cost = v_cost, total_profit = v_total - v_cost
   where id = p_sale_id;

  return p_sale_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Anular venta: devuelve el stock y deja de contar en las ganancias.
-- ---------------------------------------------------------------------------
create or replace function public.cancel_vvs_sale(p_sale_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_status text;
begin
  if not public.is_admin() then raise exception 'No tienes permisos de administrador para anular ventas.'; end if;

  select status into v_status from public.sales where id = p_sale_id for update;
  if not found then raise exception 'La venta no existe.'; end if;
  if v_status = 'cancelled' then raise exception 'Esta venta ya estaba anulada.'; end if;

  perform public._vvs_restore_sale_stock(p_sale_id);
  update public.sales set status = 'cancelled', cancelled_at = now() where id = p_sale_id;
  return p_sale_id;
end;
$$;

revoke all on function public._vvs_add_sale_item(uuid, text, uuid, integer) from public, anon, authenticated;
revoke all on function public._vvs_restore_sale_stock(uuid) from public, anon, authenticated;
revoke all on function public.register_vvs_sale(text, uuid, integer, text, text, text) from public, anon;
grant execute on function public.register_vvs_sale(text, uuid, integer, text, text, text) to authenticated;
revoke all on function public.update_vvs_sale(uuid, text, uuid, integer, text, text, text) from public, anon;
grant execute on function public.update_vvs_sale(uuid, text, uuid, integer, text, text, text) to authenticated;
revoke all on function public.cancel_vvs_sale(uuid) from public, anon;
grant execute on function public.cancel_vvs_sale(uuid) to authenticated;
grant execute on function public.is_admin() to authenticated;

-- 6) Verificación (opcional): debe devolver tu correo y NINGUNA otra cuenta desconocida
-- select u.email from public.admin_users a join auth.users u on u.id = a.user_id;
