-- ============================================================
-- 006_rls.sql
-- Row Level Security en todas las tablas y matriz de permisos.
-- La interfaz oculta botones; esto es lo que decide de verdad.
-- ============================================================

-- ------------------------------------------------------------
-- MATRIZ DE PERMISOS
-- ------------------------------------------------------------

insert into permisos (rol_id, recurso, accion)
select r.id, x.recurso, x.accion
from roles r
cross join lateral (values
  -- admin: todo
  ('admin','productos','read'),   ('admin','productos','create'),
  ('admin','productos','update'), ('admin','productos','delete'),
  ('admin','clientes','read'),    ('admin','clientes','create'),
  ('admin','clientes','update'),  ('admin','clientes','delete'),
  ('admin','ventas','read'),      ('admin','ventas','create'),
  ('admin','ventas','update'),    ('admin','ventas','confirm'),
  ('admin','ventas','cancel'),
  ('admin','compras','read'),     ('admin','compras','create'),
  ('admin','compras','update'),   ('admin','compras','confirm'),
  ('admin','compras','cancel'),
  ('admin','stock','read'),       ('admin','stock','update'),
  ('admin','informes','read'),    ('admin','informes','costos'),
  ('admin','usuarios','read'),    ('admin','usuarios','update'),

  -- gerente: todo menos gestión de usuarios
  ('gerente','productos','read'),  ('gerente','productos','create'),
  ('gerente','productos','update'),
  ('gerente','clientes','read'),   ('gerente','clientes','create'),
  ('gerente','clientes','update'),
  ('gerente','ventas','read'),     ('gerente','ventas','create'),
  ('gerente','ventas','update'),   ('gerente','ventas','confirm'),
  ('gerente','ventas','cancel'),
  ('gerente','compras','read'),    ('gerente','compras','create'),
  ('gerente','compras','update'),  ('gerente','compras','confirm'),
  ('gerente','compras','cancel'),
  ('gerente','stock','read'),      ('gerente','stock','update'),
  ('gerente','informes','read'),   ('gerente','informes','costos'),

  -- vendedor: vende, no ve costes ni compras
  ('vendedor','productos','read'),
  ('vendedor','clientes','read'),  ('vendedor','clientes','create'),
  ('vendedor','ventas','read'),    ('vendedor','ventas','create'),
  ('vendedor','ventas','update'),  ('vendedor','ventas','confirm'),
  ('vendedor','stock','read'),
  ('vendedor','informes','read'),

  -- almacén: mueve mercadería, no factura
  ('almacen','productos','read'),  ('almacen','productos','update'),
  ('almacen','compras','read'),    ('almacen','compras','create'),
  ('almacen','compras','confirm'),
  ('almacen','stock','read'),      ('almacen','stock','update'),
  ('almacen','ventas','read'),

  -- lectura
  ('lectura','productos','read'),
  ('lectura','clientes','read'),
  ('lectura','ventas','read'),
  ('lectura','stock','read'),
  ('lectura','informes','read')
) as x(rol, recurso, accion)
where r.codigo = x.rol;

-- ------------------------------------------------------------
-- ACTIVAR RLS
-- Se activa en todas, incluidos los catálogos. Un catálogo sin RLS
-- en Supabase es una tabla abierta a internet.
-- ------------------------------------------------------------

alter table profiles              enable row level security;
alter table roles                 enable row level security;
alter table permisos              enable row level security;
alter table sucursales            enable row level security;
alter table almacenes             enable row level security;
alter table zonas                 enable row level security;
alter table vendedores            enable row level security;
alter table transportes           enable row level security;
alter table condiciones_pago      enable row level security;
alter table clientes              enable row level security;
alter table proveedores           enable row level security;
alter table familias              enable row level security;
alter table productos             enable row level security;
alter table presentaciones        enable row level security;
alter table listas_precio         enable row level security;
alter table precios               enable row level security;
alter table series                enable row level security;
alter table documentos            enable row level security;
alter table documento_lineas      enable row level security;
alter table documento_cuotas      enable row level security;
alter table cpe_envios            enable row level security;
alter table movimientos_stock     enable row level security;
alter table tipos_documento       enable row level security;
alter table monedas               enable row level security;
alter table cat_tipo_comprobante  enable row level security;
alter table cat_tipo_doc_identidad enable row level security;
alter table cat_afectacion_igv    enable row level security;
alter table cat_unidad_medida     enable row level security;
alter table cat_motivo_nc         enable row level security;
alter table cat_motivo_nd         enable row level security;

-- ------------------------------------------------------------
-- CATÁLOGOS: lectura para cualquier autenticado, escritura solo admin
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
    execute format(
      'create policy %I_lectura on %I for select to authenticated using (true)', t, t);
    execute format(
      'create policy %I_admin on %I for all to authenticated
         using (app.es_admin()) with check (app.es_admin())', t, t);
  end loop;
end $$;

-- ------------------------------------------------------------
-- PERFILES
-- ------------------------------------------------------------

create policy profiles_propio on profiles
  for select to authenticated
  using (id = auth.uid() or app.tiene_permiso('usuarios','read'));

create policy profiles_admin on profiles
  for all to authenticated
  using (app.tiene_permiso('usuarios','update'))
  with check (app.tiene_permiso('usuarios','update'));

create policy permisos_lectura on permisos
  for select to authenticated using (true);

-- ------------------------------------------------------------
-- PRODUCTOS Y PRECIOS
-- ------------------------------------------------------------

create policy productos_read on productos
  for select to authenticated using (app.tiene_permiso('productos','read'));
create policy productos_insert on productos
  for insert to authenticated with check (app.tiene_permiso('productos','create'));
create policy productos_update on productos
  for update to authenticated
  using (app.tiene_permiso('productos','update'))
  with check (app.tiene_permiso('productos','update'));

create policy presentaciones_read on presentaciones
  for select to authenticated using (app.tiene_permiso('productos','read'));
create policy presentaciones_write on presentaciones
  for all to authenticated
  using (app.tiene_permiso('productos','update'))
  with check (app.tiene_permiso('productos','update'));

create policy precios_read on precios
  for select to authenticated using (app.tiene_permiso('productos','read'));
create policy precios_write on precios
  for all to authenticated
  using (app.tiene_permiso('productos','update'))
  with check (app.tiene_permiso('productos','update'));

-- ------------------------------------------------------------
-- CLIENTES Y PROVEEDORES
--
-- El vendedor solo ve su cartera. Si se quiere que vea todo,
-- basta con quitar la condición del vendedor_id.
-- ------------------------------------------------------------

create policy clientes_read on clientes
  for select to authenticated
  using (
    app.tiene_permiso('clientes','read')
    and (
      app.rol_actual() <> 'vendedor'
      or vendedor_id is null
      or vendedor_id = (select vendedor_id from profiles where id = auth.uid())
    )
  );

create policy clientes_insert on clientes
  for insert to authenticated with check (app.tiene_permiso('clientes','create'));
create policy clientes_update on clientes
  for update to authenticated
  using (app.tiene_permiso('clientes','update'))
  with check (app.tiene_permiso('clientes','update'));

create policy proveedores_read on proveedores
  for select to authenticated using (app.tiene_permiso('compras','read'));
create policy proveedores_write on proveedores
  for all to authenticated
  using (app.tiene_permiso('compras','update'))
  with check (app.tiene_permiso('compras','update'));

-- ------------------------------------------------------------
-- DOCUMENTOS
--
-- El recurso depende de si el tipo es compra o venta, así que las
-- políticas lo resuelven con una subconsulta al catálogo.
-- ------------------------------------------------------------

create or replace function app.recurso_de(p_tipo text)
returns text language sql stable as $$
  select case when es_compra then 'compras' else 'ventas' end
    from public.tipos_documento where codigo = p_tipo;
$$;

create policy documentos_read on documentos
  for select to authenticated
  using (
    app.tiene_permiso(app.recurso_de(tipo_documento), 'read')
    and (
      app.rol_actual() <> 'vendedor'
      or vendedor_id is null
      or vendedor_id = (select vendedor_id from profiles where id = auth.uid())
    )
  );

create policy documentos_insert on documentos
  for insert to authenticated
  with check (
    app.tiene_permiso(app.recurso_de(tipo_documento), 'create')
    and estado = 'BORRADOR'
    and creado_por = auth.uid()
  );

-- Solo se edita en BORRADOR. Un documento confirmado es inmutable
-- desde el cliente; los cambios de estado pasan por las funciones
-- SECURITY DEFINER de 005.
create policy documentos_update on documentos
  for update to authenticated
  using (
    estado = 'BORRADOR'
    and app.tiene_permiso(app.recurso_de(tipo_documento), 'update')
  )
  with check (estado = 'BORRADOR');

create policy lineas_read on documento_lineas
  for select to authenticated
  using (exists (select 1 from documentos d where d.id = documento_id));

create policy lineas_write on documento_lineas
  for all to authenticated
  using (
    exists (select 1 from documentos d
             where d.id = documento_id
               and d.estado = 'BORRADOR'
               and app.tiene_permiso(app.recurso_de(d.tipo_documento), 'update'))
  )
  with check (
    exists (select 1 from documentos d
             where d.id = documento_id and d.estado = 'BORRADOR')
  );

create policy cuotas_read on documento_cuotas
  for select to authenticated
  using (exists (select 1 from documentos d where d.id = documento_id));

-- ------------------------------------------------------------
-- STOCK: lectura según permiso, escritura solo por función
-- ------------------------------------------------------------

create policy stock_read on movimientos_stock
  for select to authenticated using (app.tiene_permiso('stock','read'));

-- Sin política de INSERT a propósito: los movimientos solo los
-- crean confirmar_documento() y anular_documento(), que son
-- SECURITY DEFINER y saltan RLS. Nadie inserta stock a mano.

create policy series_read on series
  for select to authenticated using (true);

create policy cpe_read on cpe_envios
  for select to authenticated using (app.tiene_permiso('ventas','read'));

-- ------------------------------------------------------------
-- COSTES: vista de márgenes solo para quien tiene informes.costos
-- ------------------------------------------------------------

create view v_margen_ventas
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
  where d.estado in ('EMITIDO','ENVIANDO','ACEPTADO','OBSERVADO')
    and app.tiene_permiso('informes','costos');
