-- VVS Jewelry: corrección del módulo de ventas.
-- Ejecutar en Supabase > SQL Editor DESPUÉS de vvs-sales-stock-update.sql.
-- Es seguro ejecutarlo más de una vez.
--
-- Qué corrige:
--  1) Falta la columna sales.status -> el panel mostraba "No se pudo cargar el historial".
--  2) Faltaban las funciones cancel_vvs_sale y update_vvs_sale (botones Anular y Editar).
--  3) register_vvs_sale ignoraba el precio de oferta y registraba la venta a precio normal.

alter table public.sales
  add column if not exists status text not null default 'active',
  add column if not exists cancelled_at timestamptz;

-- Elimina las versiones anteriores de estas funciones (pueden existir con otro tipo de retorno).
drop function if exists public.update_vvs_sale(uuid, text, uuid, integer, text, text, text);
drop function if exists public.cancel_vvs_sale(uuid);
drop function if exists public.register_vvs_sale(text, uuid, integer, text, text, text);
drop function if exists public._vvs_add_sale_item(uuid, text, uuid, integer);
drop function if exists public._vvs_restore_sale_stock(uuid);

-- ---------------------------------------------------------------------------
-- Auxiliar: descuenta stock y guarda la línea de venta (usa precio de oferta si existe).
-- ---------------------------------------------------------------------------
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
set search_path = public
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
set search_path = public
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

revoke all on function public._vvs_add_sale_item(uuid, text, uuid, integer) from public;
revoke all on function public._vvs_restore_sale_stock(uuid) from public;

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
set search_path = public
as $$
declare
  v_sale_id uuid;
  v_total integer;
  v_cost integer;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión para registrar ventas.'; end if;
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
set search_path = public
as $$
declare
  v_status text;
  v_total integer;
  v_cost integer;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión para editar ventas.'; end if;
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
set search_path = public
as $$
declare
  v_status text;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión para anular ventas.'; end if;

  select status into v_status from public.sales where id = p_sale_id for update;
  if not found then raise exception 'La venta no existe.'; end if;
  if v_status = 'cancelled' then raise exception 'Esta venta ya estaba anulada.'; end if;

  perform public._vvs_restore_sale_stock(p_sale_id);
  update public.sales set status = 'cancelled', cancelled_at = now() where id = p_sale_id;
  return p_sale_id;
end;
$$;

revoke all on function public.register_vvs_sale(text, uuid, integer, text, text, text) from public;
grant execute on function public.register_vvs_sale(text, uuid, integer, text, text, text) to authenticated;
revoke all on function public.update_vvs_sale(uuid, text, uuid, integer, text, text, text) from public;
grant execute on function public.update_vvs_sale(uuid, text, uuid, integer, text, text, text) to authenticated;
revoke all on function public.cancel_vvs_sale(uuid) from public;
grant execute on function public.cancel_vvs_sale(uuid) to authenticated;
