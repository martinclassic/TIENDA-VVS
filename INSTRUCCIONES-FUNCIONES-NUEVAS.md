# VVS Jewelry — actualización de funciones del administrador

Esta actualización agrega:
- Registro de ventas individuales de productos o packs.
- Historial de hasta las últimas 100 ventas.
- Resumen de total vendido y ganancia estimada a partir de los costos guardados al momento de vender.
- Alertas de stock: agotado (0) y pocas unidades (1–2).
- Campo de descuento porcentual en la ficha de cada producto; el precio de oferta se calcula y continúa usando `promo_price`, por lo que la tienda pública existente ya lo puede mostrar.

## Instalación segura

1. Haz una copia de seguridad de tu repositorio actual antes de cambiar archivos.
2. En Supabase, abre **SQL Editor > New query**, pega el contenido completo de `vvs-sales-stock-update.sql` y ejecuta una sola vez. Este script crea las tablas de ventas, las políticas de acceso y la función transaccional que registra la venta y descuenta inventario. No borra productos, packs ni ajustes existentes.
3. En GitHub, reemplaza únicamente `admin.html`, `admin.js` y `admin.css` por los de esta actualización. Sube también `vvs-sales-stock-update.sql` e `INSTRUCCIONES-FUNCIONES-NUEVAS.md`.
4. **No reemplaces `config.js`, `index.html`, `app.js` ni `styles.css`.** Así mantienes tus credenciales actuales y el diseño público sin cambios.
5. Espera el despliegue de Cloudflare, entra a `/admin.html`, inicia sesión y abre la pestaña **Ventas**.
6. Prueba primero con una venta pequeña y verifica el historial y el stock. Puedes borrar el registro de prueba desde Supabase si fuera necesario, pero el stock descontado deberá restaurarse manualmente desde el administrador antes de hacerlo.

## Cómo registrar una venta

1. Confirma el pedido por WhatsApp.
2. En el administrador, abre **Ventas > Registrar venta**.
3. Selecciona el producto o pack, ingresa cantidad y, si quieres, nombre/contacto del cliente.
4. Confirma. Si hay stock suficiente, la venta se guarda y el inventario se descuenta en una sola transacción. Si no hay stock, la operación completa falla y no registra una venta parcial.

## Cómo aplicar un descuento

1. Abre **Productos > Editar** o **Añadir producto**.
2. Escribe el porcentaje en **Descuento (%)**. El precio de oferta se calcula automáticamente.
3. Guarda el producto. La tienda pública seguirá mostrando el precio rebajado usando el campo `promo_price` ya existente.

## Consideraciones

- La alerta de pocas unidades se activa cuando el stock es 1 o 2; agotado es 0.
- El historial conserva el nombre, precio y costo usados en cada venta, para que cambiar el precio/costo del producto después no altere ventas antiguas.
- La ganancia es estimada: venta menos costo registrado. No descuenta despacho, comisiones, publicidad ni impuestos.
- Para un pack se descuenta la cantidad correspondiente de cada producto asociado en `pack_items`. La función impide completar la venta si falta stock de cualquiera de sus componentes.
- La función de venta solo se ejecuta para usuarios autenticados. Mantén desactivados los registros públicos de usuarios en Supabase.
