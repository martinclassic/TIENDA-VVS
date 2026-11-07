-- VVS Jewelry: registro de gastos en insumos.
-- Ejecutar una vez en Supabase > SQL Editor. Es seguro repetirlo.

create table if not exists public.supply_expenses (
  id uuid primary key default gen_random_uuid(),
  spent_at date not null default current_date,
  description text not null,
  category text,
  amount integer not null check (amount >= 0),
  notes text,
  created_at timestamptz not null default now()
);

alter table public.supply_expenses enable row level security;

drop policy if exists "Admins manage supply expenses" on public.supply_expenses;
create policy "Admins manage supply expenses" on public.supply_expenses
  for all to authenticated using (true) with check (true);

grant select, insert, update, delete on public.supply_expenses to authenticated;
