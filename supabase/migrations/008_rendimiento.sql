-- ============================================================
-- 008_rendimiento.sql
-- Dos ajustes de rendimiento sobre lo creado en 003/004/006:
--
-- 1. Políticas RLS que llaman a auth.uid()/app.rol_actual()/
--    app.tiene_permiso() sin envolverlos en `(select ...)`. Postgres
--    los invoca una vez POR FILA; envueltos en subconsulta, el
--    planner los trata como InitPlan y los evalúa una sola vez por
--    consulta. Esto solo ayuda cuando los argumentos son constantes
--    de la propia política (literales, auth.uid()); las políticas de
--    `documentos`/`documento_lineas` que llaman a
--    app.recurso_de(tipo_documento) reciben una columna de cada fila
--    como argumento, así que ese envoltorio no les cambia el plan y
--    no se tocan aquí. Si esas tablas crecen mucho, la solución real
--    es desnormalizar `recurso` en la propia fila, no forzar el
--    envoltorio.
--    Ver: https://supabase.com/docs/guides/database/postgres/row-level-security#rls-performance-recommendations
--
-- 2. Índices que faltan sobre columnas FK que sí se consultan en el
--    camino caliente de la app (filtros de RLS o pantallas del
--    spec), verificados contra 002/003/004: no se repiten los que ya
--    quedan cubiertos por una unique() o un índice existente cuya
--    primera columna coincide.
-- ============================================================

-- ------------------------------------------------------------
-- RLS: catálogos (política _admin del loop de 006)
-- ------------------------------------------------------------

do $$
declare t text;
begin
  foreach t in array array[
    'tipos_documento','monedas','cat_tipo_comprobante','cat_tipo_doc_identidad',
    'cat_afectacion_igv','cat_unidad_medida','cat_motivo_nc','cat_motivo_nd',
    'roles','sucursales','almacenes','zonas','vendedores','transportes',
    'condiciones_pago','familias','listas_precio'
  ] loop
    execute format('drop policy if exists %I_admin on %I', t, t);
    execute format(
      'create policy %I_admin on %I for all to authenticated
         using ((select app.es_admin())) with check ((select app.es_admin()))', t, t);
  end loop;
end $$;

-- ------------------------------------------------------------
-- RLS: perfiles
-- ------------------------------------------------------------

drop policy if exists profiles_propio on profiles;
create policy profiles_propio on profiles
  for select to authenticated
  using (id = (select auth.uid()) or (select app.tiene_permiso('usuarios', 'read')));

drop policy if exists profiles_admin on profiles;
create policy profiles_admin on profiles
  for all to authenticated
  using ((select app.tiene_permiso('usuarios', 'update')))
  with check ((select app.tiene_permiso('usuarios', 'update')));

-- ------------------------------------------------------------
-- RLS: productos y precios
-- ------------------------------------------------------------

drop policy if exists productos_read on productos;
create policy productos_read on productos
  for select to authenticated using ((select app.tiene_permiso('productos', 'read')));

drop policy if exists productos_insert on productos;
create policy productos_insert on productos
  for insert to authenticated with check ((select app.tiene_permiso('productos', 'create')));

drop policy if exists productos_update on productos;
create policy productos_update on productos
  for update to authenticated
  using ((select app.tiene_permiso('productos', 'update')))
  with check ((select app.tiene_permiso('productos', 'update')));

drop policy if exists presentaciones_read on presentaciones;
create policy presentaciones_read on presentaciones
  for select to authenticated using ((select app.tiene_permiso('productos', 'read')));

drop policy if exists presentaciones_write on presentaciones;
create policy presentaciones_write on presentaciones
  for all to authenticated
  using ((select app.tiene_permiso('productos', 'update')))
  with check ((select app.tiene_permiso('productos', 'update')));

drop policy if exists precios_read on precios;
create policy precios_read on precios
  for select to authenticated using ((select app.tiene_permiso('productos', 'read')));

drop policy if exists precios_write on precios;
create policy precios_write on precios
  for all to authenticated
  using ((select app.tiene_permiso('productos', 'update')))
  with check ((select app.tiene_permiso('productos', 'update')));

-- ------------------------------------------------------------
-- RLS: clientes y proveedores
-- ------------------------------------------------------------

drop policy if exists clientes_read on clientes;
create policy clientes_read on clientes
  for select to authenticated
  using (
    (select app.tiene_permiso('clientes', 'read'))
    and (
      (select app.rol_actual()) <> 'vendedor'
      or vendedor_id is null
      or vendedor_id = (select vendedor_id from profiles where id = (select auth.uid()))
    )
  );

drop policy if exists clientes_insert on clientes;
create policy clientes_insert on clientes
  for insert to authenticated with check ((select app.tiene_permiso('clientes', 'create')));

drop policy if exists clientes_update on clientes;
create policy clientes_update on clientes
  for update to authenticated
  using ((select app.tiene_permiso('clientes', 'update')))
  with check ((select app.tiene_permiso('clientes', 'update')));

drop policy if exists proveedores_read on proveedores;
create policy proveedores_read on proveedores
  for select to authenticated using ((select app.tiene_permiso('compras', 'read')));

drop policy if exists proveedores_write on proveedores;
create policy proveedores_write on proveedores
  for all to authenticated
  using ((select app.tiene_permiso('compras', 'update')))
  with check ((select app.tiene_permiso('compras', 'update')));

-- ------------------------------------------------------------
-- RLS: documentos
--
-- Solo se envuelven auth.uid() y app.rol_actual(): son constantes
-- por consulta. app.tiene_permiso(app.recurso_de(tipo_documento), …)
-- se deja igual que en 006 a propósito (ver cabecera del archivo).
-- ------------------------------------------------------------

drop policy if exists documentos_read on documentos;
create policy documentos_read on documentos
  for select to authenticated
  using (
    app.tiene_permiso(app.recurso_de(tipo_documento), 'read')
    and (
      (select app.rol_actual()) <> 'vendedor'
      or vendedor_id is null
      or vendedor_id = (select vendedor_id from profiles where id = (select auth.uid()))
    )
  );

drop policy if exists documentos_insert on documentos;
create policy documentos_insert on documentos
  for insert to authenticated
  with check (
    app.tiene_permiso(app.recurso_de(tipo_documento), 'create')
    and estado = 'BORRADOR'
    and creado_por = (select auth.uid())
  );

-- documentos_update y lineas_write no cambian: no tienen ningún
-- auth.uid()/rol_actual() de sobra, solo el recurso_de(...) por fila.

-- ------------------------------------------------------------
-- RLS: stock y CPE
-- ------------------------------------------------------------

drop policy if exists stock_read on movimientos_stock;
create policy stock_read on movimientos_stock
  for select to authenticated using ((select app.tiene_permiso('stock', 'read')));

drop policy if exists cpe_read on cpe_envios;
create policy cpe_read on cpe_envios
  for select to authenticated using ((select app.tiene_permiso('ventas', 'read')));

-- ------------------------------------------------------------
-- RLS: vista de márgenes
-- ------------------------------------------------------------

create or replace view v_margen_ventas
with (security_invoker = true) as
  select
    d.id as documento_id, d.tipo_documento, d.serie, d.correlativo,
    d.fecha_emision, d.cliente_id,
    dl.producto_id, dl.descripcion, dl.cantidad_base,
    dl.valor_venta,
    dl.coste_unitario_snapshot * dl.cantidad_base as coste_total,
    dl.valor_venta - (dl.coste_unitario_snapshot * dl.cantidad_base) as margen
  from documentos d
  join documento_lineas dl on dl.documento_id = d.id
  where d.estado in ('EMITIDO', 'ENVIANDO', 'ACEPTADO', 'OBSERVADO')
    and (select app.tiene_permiso('informes', 'costos'));

-- ------------------------------------------------------------
-- ÍNDICES FALTANTES SOBRE FK
--
-- El resto de FK de 001-004 ya quedan cubiertas por una unique() o
-- un índice existente cuya primera columna coincide (por ejemplo,
-- documento_lineas.documento_id por unique(documento_id,
-- numero_linea), o almacenes.sucursal_id por unique(sucursal_id,
-- codigo)). Estas no lo estaban.
-- ------------------------------------------------------------

-- documentos_read filtra por vendedor_id en cada consulta de un
-- vendedor; es la tabla más grande del sistema.
create index if not exists documentos_vendedor_idx
  on documentos (vendedor_id, fecha_emision desc);

create index if not exists documentos_proveedor_idx
  on documentos (proveedor_id, fecha_emision desc);

-- clientes_read hace el mismo filtro por vendedor_id.
create index if not exists clientes_vendedor_idx
  on clientes (vendedor_id) where activo;

-- Ficha de producto lista las presentaciones de un producto; los
-- índices únicos existentes solo cubren la base/default, no "todas".
create index if not exists presentaciones_producto_idx
  on presentaciones (producto_id) where activo;

create index if not exists cpe_envios_documento_idx
  on cpe_envios (documento_id);
