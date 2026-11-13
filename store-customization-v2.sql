-- VVS Jewelry: personalización avanzada de la tienda.
-- Ejecutar una vez en Supabase > SQL Editor (es seguro repetirlo).
-- Las fotos se suben al mismo almacenamiento "product-images" de los productos
-- (requiere haber ejecutado product-gallery-update.sql).

alter table public.store_settings
  add column if not exists whatsapp text,
  add column if not exists instagram_url text,
  add column if not exists about_image text,
  add column if not exists contact_button text,
  add column if not exists value1_title text,
  add column if not exists value1_text text,
  add column if not exists value2_title text,
  add column if not exists value2_text text,
  add column if not exists value3_title text,
  add column if not exists value3_text text,
  add column if not exists heading_font text not null default 'Playfair Display',
  add column if not exists body_font text not null default 'DM Sans',
  add column if not exists dark_color text not null default '#171512',
  add column if not exists button_style text not null default 'square',
  add column if not exists show_values boolean not null default true,
  add column if not exists show_packs boolean not null default true,
  add column if not exists show_about boolean not null default true;
