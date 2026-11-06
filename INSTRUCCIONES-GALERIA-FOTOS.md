# Actualización: carga de fotografías y galería de productos

## Qué incorpora
- En el administrador, el formulario de producto permite seleccionar varias fotografías desde el computador o teléfono.
- Las imágenes se suben directamente a Supabase Storage (bucket `product-images`).
- Se muestra una vista previa y se pueden quitar imágenes de la galería desde el formulario.
- La tienda abre una ficha de producto al pincharlo, con imagen principal, miniaturas, flechas, descripción, precio, stock y botón de WhatsApp.
- Se conserva `products.image_url` como imagen principal para compatibilidad con los productos actuales.

## Paso 1: ejecutar la migración de Supabase
1. Entra a tu proyecto Supabase.
2. Abre **SQL Editor**.
3. Crea una consulta nueva.
4. Copia y ejecuta todo el contenido de `product-gallery-update.sql`.
5. Confirma que la consulta termine sin errores.

La migración crea el bucket público `product-images`, la tabla `product_images`, sus políticas de acceso y copia las imágenes principales actuales a la galería.

## Paso 2: publicar los archivos
Reemplaza en tu repositorio los archivos por los de esta actualización:
- `admin.html`
- `admin.js`
- `admin.css`
- `app.js`
- `styles.css`

También agrega `product-gallery-update.sql` al repositorio para conservar la migración como respaldo. No reemplaces `config.js`: conserva tu URL y clave anon actuales.

Haz commit y push a la rama que despliega tu Cloudflare Worker.

## Paso 3: probar
1. Abre `/admin.html` e inicia sesión.
2. Edita un producto o crea uno nuevo.
3. En **Fotografías del producto**, selecciona 2 o más imágenes.
4. Guarda y espera el mensaje de confirmación.
5. Abre la tienda pública y pincha el producto.
6. Comprueba las miniaturas, flechas y botón de WhatsApp.

## Importante
- El bucket es público para que los visitantes puedan ver las fotos; la carga y eliminación requieren iniciar sesión como administrador.
- No publiques nunca la clave `service_role`. La tienda sigue usando la clave anon de `config.js`.
- El límite configurado por imagen es 10 MB y se aceptan JPG, PNG, WEBP y AVIF.
- Esta versión conserva las imágenes antiguas; si un producto solo tenía `image_url`, se incorpora a su galería al guardarlo desde el administrador.
