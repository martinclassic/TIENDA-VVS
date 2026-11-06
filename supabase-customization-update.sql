-- VVS Jewelry: ampliación de personalización de la tienda
-- Ejecuta este archivo UNA SOLA VEZ en Supabase > SQL Editor.
alter table public.store_settings
  add column if not exists brand_name text not null default 'JEWELRY',
  add column if not exists logo_url text,
  add column if not exists hero_eyebrow text not null default 'MENOS, PERO MEJOR',
  add column if not exists collection_title text not null default 'Piezas para llevar a tu manera.',
  add column if not exists collection_text text not null default 'Una buena pieza no necesita llamar la atención todo el tiempo. Solo tiene que sentirse tuya.',
  add column if not exists packs_title text not null default 'Los favoritos, juntos.',
  add column if not exists packs_text text not null default 'Arma tu combinación ideal o pregunta por nuestros packs disponibles. A veces, el mejor detalle es llevarse los dos.',
  add column if not exists about_title text not null default 'El lujo también está en lo simple.',
  add column if not exists about_text1 text not null default 'VVS Jewelry nace de una idea sencilla: encontrar piezas que se vean bien, se sientan especiales y sean fáciles de combinar con tu propio estilo.',
  add column if not exists about_text2 text not null default 'Estamos comenzando con una selección acotada. Por eso preferimos atenderte directamente, mostrarte los detalles y ayudarte a elegir con tranquilidad.',
  add column if not exists footer_text text not null default 'Detalles que hablan por ti.';
