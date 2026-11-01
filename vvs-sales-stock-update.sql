-- VVS Jewelry: ventas, historial, ganancias y descuento atomico de stock.
-- Ejecutar UNA sola vez en Supabase > SQL Editor.

create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  sold_at timestamptz not null default now(),
  customer_name text,
  customer_contact text,
  notes text,
  total_amount integer not null default 0 check (total_amount >= 0),
  total_cost integer not null default 0 check (total_cost >= 0),
  total_profit integer not null default 0,
  created_by uuid default auth.uid()
);

create table if not exists public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  pack_id uuid references public.packs(id) on delete set null,
  item_name text not null,
  quantity integer not null check (quantity > 0),
  unit_price integer not null check (unit_price >= 0),
  unit_cost integer not null check (unit_cost >= 0),
  line_total integer not null check (line_total >= 0),
  line_profit integer not null,
  constraint sale_item_one_type check (not (product_id is not null and pack_id is not null))
);

alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
drop policy if exists "Admins manage sales" on public.sales;
create policy "Admins manage sales" on public.sales for all to authenticated using (true) with check (true);
drop policy if exists "Admins manage sale items" on public.sale_items;
create policy "Admins manage sale items" on public.sale_items for all to authenticated using (true) with check (true);

-- Registra una venta de un producto o pack, guarda los valores históricos y descuenta stock
-- dentro de una sola transacción. Si algo falla, PostgreSQL revierte toda la operación.
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
  v_name text;
  v_price integer;
  v_cost integer;
  v_stock integer;
  v_total integer;
  v_total_cost integer;
  v_product record;
begin
  if auth.uid() is null then raise exception 'Debes iniciar sesión para registrar ventas.'; end if;
  if p_quantity is null or p_quantity < 1 then raise exception 'La cantidad debe ser al menos 1.'; end if;

  if p_item_type = 'product' then
    select name, price, cost, stock,
      case when promo_price is not null and promo_price > 0 and promo_price < price then promo_price else price end as final_price
    into v_name, v_price, v_cost, v_stock, v_total
    from public.products where id = p_item_id and active = true for update;
    if not found then raise exception 'El producto no existe o está oculto.'; end if;
    if v_stock < p_quantity then raise exception 'Stock insuficiente. Disponible: %', v_stock; end if;
    update public.products set stock = stock - p_quantity where id = p_item_id;
    v_total := v_price * p_quantity;
    v_total_cost := v_cost * p_quantity;
  elsif p_item_type = 'pack' then
    select name, price into v_name, v_price from public.packs where id = p_item_id and active = true for update;
    if not found then raise exception 'El pack no existe o está oculto.'; end if;
    if not exists(select 1 from public.pack_items where pack_id = p_item_id) then raise exception 'Este pack no tiene productos asociados.'; end if;
    v_total_cost := 0;
    for v_product in
      select pr.id, pr.name, pr.stock, pr.cost, pi.quantity as pack_quantity
      from public.pack_items pi join public.products pr on pr.id = pi.product_id
      where pi.pack_id = p_item_id order by pr.id for update of pr
    loop
      if v_product.stock < v_product.pack_quantity * p_quantity then
        raise exception 'Stock insuficiente para % (disponible: %, requerido: %).', v_product.name, v_product.stock, v_product.pack_quantity * p_quantity;
      end if;
      update public.products set stock = stock - (v_product.pack_quantity * p_quantity) where id = v_product.id;
      v_total_cost := v_total_cost + (v_product.cost * v_product.pack_quantity * p_quantity);
    end loop;
    v_total := v_price * p_quantity;
  else
    raise exception 'Tipo de artículo no válido.';
  end if;

  insert into public.sales(customer_name, customer_contact, notes, total_amount, total_cost, total_profit)
  values (nullif(trim(p_customer_name), ''), nullif(trim(p_customer_contact), ''), nullif(trim(p_notes), ''), v_total, v_total_cost, v_total - v_total_cost)
  returning id into v_sale_id;

  insert into public.sale_items(sale_id, product_id, pack_id, item_name, quantity, unit_price, unit_cost, line_total, line_profit)
  values (v_sale_id,
    case when p_item_type = 'product' then p_item_id else null end,
    case when p_item_type = 'pack' then p_item_id else null end,
    v_name, p_quantity, v_price, case when p_quantity > 0 then v_total_cost / p_quantity else 0 end,
    v_total, v_total - v_total_cost);
  return v_sale_id;
end;
$$;

revoke all on function public.register_vvs_sale(text, uuid, integer, text, text, text) from public;
grant execute on function public.register_vvs_sale(text, uuid, integer, text, text, text) to authenticated;
