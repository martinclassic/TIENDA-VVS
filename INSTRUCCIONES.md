# VVS Jewelry — sitio de catálogo y administración

Incluye catálogo público, pedidos por WhatsApp, panel privado para gestionar productos y packs, precios/costos, stock y cálculo de margen estimado. Estética sobria crema, negro y dorado; evita frases de venta exageradas.

## Antes de publicar
1. Abre `config.js` y cambia `569XXXXXXXX` por tu WhatsApp chileno completo, sin + ni espacios (formato de ejemplo: `56912345678`).
2. Añade tus fotos reales a `assets/`: `hero-earrings.jpg`, `aros-cuadrados.jpg`, `aros-redondos.jpg` y `pack-duo.jpg`. También puedes poner una URL pública de imagen en el panel admin.
3. Comprueba que precios, costos y stock son correctos. En este proyecto los costos iniciales de referencia son $9.000 y $8.000; confirma si debes sumar embalaje/envío a esos costos antes de usar el cálculo de margen.

## Conectar la base de datos (Supabase)
1. Entra a https://supabase.com/ y crea un proyecto.
2. Abre SQL Editor > New query, copia todo `supabase-schema.sql` y pulsa Run. Ejecuta el archivo solo una vez para evitar duplicar los datos iniciales.
3. Ve a Authentication > Users y crea tu usuario con correo y contraseña. Si es posible, márcalo como confirmado.
4. Desactiva el registro público de usuarios en Authentication/Sign In settings. El panel de administración debe quedar solo para ti.
5. En Project Settings > API copia Project URL y la clave pública `anon` o `publishable`.
6. Pega esos valores en `config.js` en `supabaseUrl` y `supabaseAnonKey`. Nunca pegues la clave `service_role` ni una clave secreta en el navegador.

## Publicar gratis
1. Crea un repositorio GitHub llamado `vvs-jewelry`.
2. Sube el contenido de esta carpeta al nivel principal del repositorio (no olvides `assets`).
3. En https://pages.cloudflare.com/ crea un proyecto y conéctalo con GitHub.
4. Para este sitio estático deja el comando de build vacío y usa la raíz del repositorio como directorio de salida (`/` o la opción equivalente que muestre Cloudflare).
5. Cuando publique, prueba la URL pública y luego abre `TU-URL/admin.html`.

## Uso del panel
- Entra a `TU-URL/admin.html` con el usuario creado en Supabase.
- Productos: añade, edita o elimina piezas; cambia precio, costo total por unidad, stock, foto, descripción y visibilidad.
- Packs: crea, edita o elimina packs y elige qué productos incluyen.
- La ganancia estimada por unidad es precio menos costo registrado; el margen es esa diferencia dividida por el precio de venta. No incluye entrega, comisiones, publicidad ni impuestos.
- Los botones de la tienda abren WhatsApp con un mensaje preparado. No hay carrito ni pagos en línea.

## Importante
- La tienda pública muestra solo productos con stock y activos. Ocultar un producto no lo borra.
- El panel guarda los componentes de los packs, pero no descuenta automáticamente el inventario cuando vendes por WhatsApp. Tras confirmar una venta, actualiza el stock manualmente y comprueba que haya unidades suficientes.
- Las políticas de base de datos permiten gestionar a cualquier usuario autenticado. Por eso debes desactivar el registro público y crear solo cuentas autorizadas.
- La web no verifica la autenticidad de moissanita, metal ni certificados. Publica únicamente especificaciones que puedas respaldar.
- Los planes gratuitos de proveedores pueden tener límites y cambiar con el tiempo.


## Personalización y ofertas (versión ampliada)
Después de actualizar los archivos del sitio, vuelve a ejecutar el archivo completo `supabase-schema.sql` en un proyecto Supabase nuevo. Si ya ejecutaste la versión anterior, las tablas existentes no añaden automáticamente todas las columnas nuevas; en ese caso, ejecuta estas instrucciones SQL adicionales en el SQL Editor:

```sql
alter table public.products add column if not exists promo_price integer check (promo_price is null or promo_price >= 0);
alter table public.products add column if not exists promo_label text;
alter table public.products add column if not exists featured boolean not null default false;
create table if not exists public.store_settings (id integer primary key default 1 check (id=1), topline text not null default 'PIEZAS SELECCIONADAS · CONSULTA DISPONIBILIDAD POR WHATSAPP', hero_title text not null default 'El detalle que cambia todo.', hero_subtitle text not null default 'Joyas para acompañarte todos los días. Una selección pequeña, pensada para quienes prefieren los detalles con carácter.', hero_button text not null default 'Ver colección', hero_image text, contact_text text not null default 'Hablemos de tu próxima pieza.', accent_color text not null default '#c6a56a', background_color text not null default '#f6f4ef', text_color text not null default '#1b1916', updated_at timestamptz not null default now());
insert into public.store_settings(id) values (1) on conflict (id) do nothing;
alter table public.store_settings enable row level security;
drop policy if exists \"Public can view store settings\" on public.store_settings;
create policy \"Public can view store settings\" on public.store_settings for select to anon, authenticated using (true);
drop policy if exists \"Admins manage store settings\" on public.store_settings;
create policy \"Admins manage store settings\" on public.store_settings for all to authenticated using (true) with check (true);
```
En el panel, cada producto admite precio de oferta y etiqueta (por ejemplo, OFERTA). La personalización visual permite cambiar textos, imagen de portada y colores. Recuerda: desactiva el registro público de usuarios en Supabase y crea solamente tu usuario administrador. Nunca compartas la clave `service_role`; en `config.js` solo se utiliza la clave pública anon.
