-- ============================================================
-- 004_documentos_y_stock.sql
-- Series y correlativos, documentos (ventas y compras en una sola
-- estructura), líneas, cuotas, cola de envío a SUNAT y el libro
-- de movimientos de stock.
-- ============================================================

-- ------------------------------------------------------------
-- SERIES Y CORRELATIVOS
--
-- serie como texto de 4 caracteres, no número: el sistema antiguo
-- usa '000' y '001', pero SUNAT exige 'F001' para facturas y 'B001'
-- para boletas. Dejarlo como texto evita migrar después.
-- ------------------------------------------------------------

create table series (
  id uuid primary key default gen_random_uuid(),
  tipo_documento text not null references tipos_documento(codigo),
  sucursal_id uuid not null references sucursales(id),
  serie text not null check (serie ~ '^[A-Z0-9]{1,4}$'),
  ultimo_correlativo bigint not null default 0,
  es_default boolean not null default false,
  activa boolean not null default true,
  unique (tipo_documento, sucursal_id, serie)
);

create unique index series_una_default
  on series (tipo_documento, sucursal_id) where es_default;

-- Asigna el siguiente correlativo con bloqueo de fila.
-- Sin esto, dos cajeros concurrentes emiten el mismo F001-00000123.
create or replace function app.siguiente_correlativo(p_serie_id uuid)
returns bigint
language plpgsql
as $$
declare
  v_correlativo bigint;
begin
  update public.series
     set ultimo_correlativo = ultimo_correlativo + 1
   where id = p_serie_id and activa
  returning ultimo_correlativo into v_correlativo;

  if v_correlativo is null then
    raise exception 'Serie % inexistente o inactiva', p_serie_id;
  end if;
  return v_correlativo;
end;
$$;

-- ------------------------------------------------------------
-- DOCUMENTOS
--
-- Una sola tabla para ventas y compras. El tipo_documento decide
-- el signo de stock, si es fiscal y si es compra. Es como lo hace
-- el sistema antiguo (el mismo "Generador de Documento(S)" sirve
-- para nota de salida y commercial invoice) y evita duplicar toda
-- la lógica de totales, descuentos y estados.
-- ------------------------------------------------------------

create table documentos (
  id uuid primary key default gen_random_uuid(),
  tipo_documento text not null references tipos_documento(codigo),
  serie_id uuid references series(id),
  serie text,
  correlativo bigint,

  sucursal_id uuid not null references sucursales(id),
  almacen_id uuid references almacenes(id),

  cliente_id uuid references clientes(id),
  proveedor_id uuid references proveedores(id),
  vendedor_id uuid references vendedores(id),
  transporte_id uuid references transportes(id),
  zona_id uuid references zonas(id),

  -- Tres fechas distintas, no una. La mercadería puede salir un día
  -- y facturarse otro; para stock manda fecha_almacen.
  fecha_emision date not null default current_date,
  fecha_almacen date,
  fecha_vencimiento date,

  condicion_pago_id uuid references condiciones_pago(id),
  forma_pago forma_pago not null default 'CONTADO',

  moneda text not null default 'PEN' references monedas(codigo),
  -- Congelado en el documento. Nunca se recalcula.
  tipo_cambio numeric(10,4) not null default 1 check (tipo_cambio > 0),

  -- Bandera crítica: decide toda la aritmética de la línea.
  precios_incluyen_igv boolean not null default true,
  modo_descuento modo_descuento not null default 'SUCESIVO',
  lista_precio_id uuid references listas_precio(id),

  -- Importes, todos calculados por app.recalcular_totales()
  total_gravado    numeric(14,2) not null default 0,
  total_exonerado  numeric(14,2) not null default 0,
  total_inafecto   numeric(14,2) not null default 0,
  total_exportacion numeric(14,2) not null default 0,
  total_gratuito   numeric(14,2) not null default 0,
  total_descuento  numeric(14,2) not null default 0,
  total_igv        numeric(14,2) not null default 0,
  total_isc        numeric(14,2) not null default 0,
  total_percepcion numeric(14,2) not null default 0,
  monto_detraccion numeric(14,2) not null default 0,
  importe_total    numeric(14,2) not null default 0,
  saldo_pendiente  numeric(14,2) not null default 0,

  estado estado_documento not null default 'BORRADOR',

  -- Referencia para notas de crédito y débito.
  -- Es un único FK a propósito: desde el 1 de agosto de 2026 SUNAT
  -- rechaza una nota asociada a varias facturas (error 3261 para NC,
  -- 3194 para ND). El modelo hace imposible el caso inválido.
  documento_referencia_id uuid references documentos(id),
  motivo_nota text,

  -- Vínculo con el documento de origen (nota de salida -> factura,
  -- orden de compra -> commercial invoice). Distinto de la referencia
  -- fiscal de arriba.
  documento_origen_id uuid references documentos(id),

  referencia_externa text,             -- 'INVOICE: 2025C130'
  observaciones text,

  creado_por uuid references profiles(id),
  creado_en timestamptz not null default now(),
  confirmado_por uuid references profiles(id),
  confirmado_en timestamptz,
  anulado_por uuid references profiles(id),
  anulado_en timestamptz,
  motivo_anulacion text,

  constraint doc_tercero_requerido check (
    cliente_id is not null or proveedor_id is not null
  ),
  constraint doc_nota_con_referencia check (
    tipo_documento not in ('NC','ND') or documento_referencia_id is not null
  )
);

create unique index documentos_numeracion_uk
  on documentos (tipo_documento, serie, correlativo)
  where correlativo is not null;

create index documentos_cliente_idx on documentos (cliente_id, fecha_emision desc);
create index documentos_estado_idx on documentos (estado, fecha_emision desc);
create index documentos_almacen_idx on documentos (almacen_id, fecha_almacen desc);

-- ------------------------------------------------------------
-- LÍNEAS
--
-- factor_conversion se congela aquí. Si mañana el proveedor cambia
-- el empaque de 72 a 60 unidades, los documentos viejos siguen
-- siendo correctos.
-- ------------------------------------------------------------

create table documento_lineas (
  id uuid primary key default gen_random_uuid(),
  documento_id uuid not null references documentos(id) on delete cascade,
  numero_linea int not null,

  producto_id uuid references productos(id),
  presentacion_id uuid references presentaciones(id),

  -- Snapshots: el documento no cambia si el catálogo cambia
  sku text,
  descripcion text not null,
  codigo_producto_sunat text,
  unidad_medida text not null references cat_unidad_medida(codigo),

  cantidad numeric(14,3) not null check (cantidad >= 0),
  factor_conversion numeric(14,6) not null default 1 check (factor_conversion > 0),
  cantidad_base numeric(14,3)
    generated always as (cantidad * factor_conversion) stored,

  -- Cuatro decimales. Este es el punto donde el sistema antiguo
  -- acierta: 22.0894, no 22.08.
  precio_unitario numeric(14,4) not null default 0,

  -- Tres niveles de descuento. El antiguo tiene cinco (Dto1..Dto5);
  -- en la práctica se usan dos o tres. Si hace falta el cuarto,
  -- se añade la columna y se ajusta app.recalcular_totales().
  dto1_pct numeric(7,4) not null default 0,
  dto2_pct numeric(7,4) not null default 0,
  dto3_pct numeric(7,4) not null default 0,
  descuento_importe numeric(14,2) not null default 0,
  precio_neto numeric(14,4) not null default 0,

  afectacion_igv text not null default '10' references cat_afectacion_igv(codigo),
  tasa_igv numeric(5,4) not null default 0.18,

  valor_venta numeric(14,2) not null default 0,   -- sin IGV
  igv_linea   numeric(14,2) not null default 0,
  isc_linea   numeric(14,2) not null default 0,
  total_linea numeric(14,2) not null default 0,   -- con IGV

  -- Congela el coste del momento. Sin esto, el margen de una venta
  -- de enero cambia cada vez que se compra más barato.
  coste_unitario_snapshot numeric(14,4) not null default 0,

  unique (documento_id, numero_linea)
);

create index documento_lineas_producto_idx on documento_lineas (producto_id);

-- ------------------------------------------------------------
-- CUOTAS
-- SUNAT exige, cuando la forma de pago es crédito, el monto neto
-- pendiente y la fecha y el importe de cada cuota.
-- ------------------------------------------------------------

create table documento_cuotas (
  id uuid primary key default gen_random_uuid(),
  documento_id uuid not null references documentos(id) on delete cascade,
  numero int not null,
  fecha_vencimiento date not null,
  monto numeric(14,2) not null check (monto > 0),
  monto_pagado numeric(14,2) not null default 0,
  unique (documento_id, numero)
);

-- ------------------------------------------------------------
-- COLA DE ENVÍO A SUNAT / PSE
--
-- El envío nunca es síncrono desde Flutter. El documento se confirma
-- rápido en Postgres y una Edge Function vacía esta cola.
-- Plazo legal: hasta 3 días calendario posteriores a la fecha de
-- emisión (R.S. 003-2023/SUNAT). Pasado el plazo, lo no enviado no
-- tiene calidad de comprobante electrónico.
-- ------------------------------------------------------------

create table cpe_envios (
  id uuid primary key default gen_random_uuid(),
  documento_id uuid not null references documentos(id) on delete cascade,
  estado estado_envio_cpe not null default 'PENDIENTE',
  intentos int not null default 0,
  -- Evita emitir dos veces si el worker reintenta tras un timeout
  -- en el que el PSE sí recibió.
  clave_idempotencia text not null unique,
  proximo_intento_en timestamptz not null default now(),
  enviado_en timestamptz,
  respondido_en timestamptz,
  codigo_respuesta text,
  descripcion_respuesta text,
  xml_path text,                      -- Supabase Storage
  cdr_path text,
  hash_cpe text,
  pdf_path text,
  payload_enviado jsonb,
  respuesta_cruda jsonb
);

create index cpe_envios_pendientes_idx
  on cpe_envios (proximo_intento_en)
  where estado in ('PENDIENTE', 'ERROR_TECNICO');

-- ------------------------------------------------------------
-- STOCK COMO LIBRO DE MOVIMIENTOS
--
-- No hay columna 'stock' en productos. El stock es la suma de este
-- libro. Siempre en unidad base, nunca en cajas.
-- ------------------------------------------------------------

create table movimientos_stock (
  id bigserial primary key,
  almacen_id uuid not null references almacenes(id),
  producto_id uuid not null references productos(id),
  tipo tipo_movimiento not null,
  signo smallint not null check (signo in (-1, 1)),
  cantidad_base numeric(14,3) not null check (cantidad_base > 0),
  coste_unitario numeric(14,4) not null default 0,
  documento_id uuid references documentos(id),
  documento_linea_id uuid references documento_lineas(id),
  fecha timestamptz not null default now(),
  creado_por uuid references profiles(id),
  nota text
);

create index movimientos_stock_saldo_idx
  on movimientos_stock (almacen_id, producto_id, fecha);
create index movimientos_stock_documento_idx
  on movimientos_stock (documento_id);

create view stock_actual as
  select
    m.almacen_id,
    m.producto_id,
    sum(m.cantidad_base * m.signo) as cantidad
  from movimientos_stock m
  group by m.almacen_id, m.producto_id;

-- Para volumen alto, sustituir la vista por una tabla de saldos
-- mantenida con trigger sobre movimientos_stock. La vista se queda
-- como fuente de verdad para reconciliar.
