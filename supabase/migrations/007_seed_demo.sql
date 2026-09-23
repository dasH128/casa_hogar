-- ============================================================
-- 007_seed_demo.sql
-- Datos de demo reconstruidos a partir de las dos capturas.
--
-- Los precios de 4 decimales están deducidos de los totales de la
-- factura: la pantalla muestra 22.08 pero 186 x 22.08 = 4,106.88,
-- mientras que el total impreso es 4,108.64, lo que implica
-- 22.0894. Mismo patrón en las nueve líneas.
--
-- Los códigos y descripciones se leyeron de una foto de pantalla
-- con reflejos, así que conviene contrastarlos con el maestro real
-- antes de usarlos para nada más que la demo.
-- ============================================================

-- ------------------------------------------------------------
-- ORGANIZACIÓN
-- ------------------------------------------------------------

insert into sucursales (codigo, nombre, codigo_establecimiento_sunat)
values ('M', 'DISTRIBUIDORA MORELLA', '0000');

insert into almacenes (sucursal_id, codigo, nombre)
select id, 'VIC', 'MORELLA - VICTORIA' from sucursales where codigo = 'M';

insert into vendedores (codigo, nombre) values
  ('V001', 'ANGELA'),
  ('V002', 'JAMILE D');

insert into transportes (codigo, nombre) values ('000', '[NINGUNO]');

insert into zonas (codigo, nombre) values ('Z01', 'LIMA CENTRO');

-- 'CHQ DIFERIDO 15 DIAS': emisión 03/08/2026 + 15 = 18/08/2026,
-- que es exactamente el vencimiento de la captura.
insert into condiciones_pago (codigo, nombre, forma_pago, dias_credito) values
  ('CON',    'CONTADO',                'CONTADO', 0),
  ('CHQ15',  'CHQ DIFERIDO 15 DIAS',   'CREDITO', 15),
  ('CHQ30',  'CHQ DIFERIDO 30 DIAS',   'CREDITO', 30),
  ('COMPRA', 'COMPRA',                 'CONTADO', 0);

-- ------------------------------------------------------------
-- SERIES
-- ------------------------------------------------------------

insert into series (tipo_documento, sucursal_id, serie, ultimo_correlativo, es_default)
select t.codigo, s.id, t.serie, t.ultimo, true
from sucursales s
cross join (values
  ('NS', '000', 164),   -- la captura muestra NOTA DE SALIDA 000-0000164
  ('CI', '001', 70),    -- COMMERCIAL INVOICE CI:001-0000070
  ('FT', 'F001', 0),
  ('BV', 'B001', 0),
  ('NC', 'F001', 0),
  ('ND', 'F001', 0)
) as t(codigo, serie, ultimo)
where s.codigo = 'M';

-- ------------------------------------------------------------
-- TERCEROS
-- ------------------------------------------------------------

-- Persona natural con DNI y RUC vacío: le corresponde boleta.
insert into clientes
  (tipo_doc_identidad, numero_documento, razon_social,
   condicion_pago_id, vendedor_id, zona_id, limite_credito)
select '1', '44998228', 'AYDEE QUICO HANCCO',
       (select id from condiciones_pago where codigo = 'CHQ15'),
       (select id from vendedores where codigo = 'V001'),
       (select id from zonas where codigo = 'Z01'),
       0;

insert into proveedores
  (tipo_doc_identidad, numero_documento, razon_social,
   es_no_domiciliado, pais, moneda_habitual, condicion_pago_id)
select '0', null, 'NINGBO YUN RUI TRADING CO. LTD',
       true, 'CN', 'USD',
       (select id from condiciones_pago where codigo = 'COMPRA');

-- ------------------------------------------------------------
-- CATÁLOGO
-- Un solo producto por modelo, con presentaciones por empaque.
-- En el sistema antiguo P9H-RH estaba partido en 004848 (x48) y
-- 005548 (x72), enlazados por Cod.Anexo. Aquí son dos
-- presentaciones del mismo producto y el stock queda unificado.
-- ------------------------------------------------------------

insert into familias (codigo, nombre) values ('PLHOT', 'PLATO MORELLA HOTELERO');

insert into productos
  (sku, familia_id, marca, linea, modelo, tamano, forma, perfil, unidad_base, afectacion_igv)
select v.sku, f.id, 'MORELLA', 'HOTELERO', v.modelo, v.tamano,
       v.forma::forma_producto, v.perfil::perfil_producto, 'NIU', '10'
from familias f
cross join (values
  ('004847', 'P8H-RT',    8.0,  'REDONDO',  'TENDIDO'),
  ('004848', 'P9H-RH',    9.0,  'REDONDO',  'HONDO'),
  ('004849', 'P9H-RT',    9.0,  'REDONDO',  'TENDIDO'),
  ('005261', 'P9.5H-CH',  9.5,  'CUADRADO', 'HONDO'),
  ('009040', 'P9.5H-RT',  9.5,  'REDONDO',  'TENDIDO'),
  ('004845', 'P10.5H-R',  10.5, 'REDONDO',  'TENDIDO'),
  ('004844', 'P10.5H-CT', 10.5, 'CUADRADO', 'TENDIDO')
) as v(sku, modelo, tamano, forma, perfil)
where f.codigo = 'PLHOT';

-- Presentaciones. sku_legacy guarda el código que el sistema
-- antiguo usaba para ese empaque concreto, para poder importar el
-- histórico sin perder la trazabilidad.
insert into presentaciones
  (producto_id, codigo, nombre, unidad_medida, factor,
   es_base, es_default_venta, es_default_compra, sku_legacy)
select p.id, v.codigo, v.nombre, v.um, v.factor,
       v.es_base, v.def_venta, v.def_compra, v.legacy
from productos p
join (values
  ('004847', 'UND',    'UNIDAD',        'NIU', 1,  true,  true,  false, null),
  ('004847', 'CAJA72', 'CAJA X 72 UND', 'BX',  72, false, false, true,  '004847'),

  ('004848', 'UND',    'UNIDAD',        'NIU', 1,  true,  true,  false, null),
  ('004848', 'CAJA48', 'CAJA X 48 UND', 'BX',  48, false, false, false, '004848'),
  ('004848', 'CAJA72', 'CAJA X 72 UND', 'BX',  72, false, false, true,  '005548'),

  ('004849', 'UND',    'UNIDAD',        'NIU', 1,  true,  true,  false, null),
  ('004849', 'CAJA48', 'CAJA X 48 UND', 'BX',  48, false, false, false, '004849'),
  ('004849', 'CAJA72', 'CAJA X 72 UND', 'BX',  72, false, false, true,  '005547'),

  ('005261', 'UND',    'UNIDAD',        'NIU', 1,  true,  true,  false, null),
  ('005261', 'CAJA72', 'CAJA X 72 UND', 'BX',  72, false, false, true,  '005261'),

  ('009040', 'UND',    'UNIDAD',        'NIU', 1,  true,  true,  false, null),
  ('009040', 'CAJA72', 'CAJA X 72 UND', 'BX',  72, false, false, true,  '009040'),

  ('004845', 'UND',    'UNIDAD',        'NIU', 1,  true,  true,  false, null),
  ('004845', 'CAJA36', 'CAJA X 36 UND', 'BX',  36, false, false, true,  '004845'),

  ('004844', 'UND',    'UNIDAD',        'NIU', 1,  true,  true,  false, null),
  ('004844', 'CAJA36', 'CAJA X 36 UND', 'BX',  36, false, false, true,  '004844')
) as v(sku, codigo, nombre, um, factor, es_base, def_venta, def_compra, legacy)
  on v.sku = p.sku;

-- ------------------------------------------------------------
-- LISTA DE PRECIOS
-- Precios con IGV incluido, como el "Precio Neto (Incl. Impstos)"
-- de la pantalla de ventas.
-- ------------------------------------------------------------

insert into listas_precio (codigo, nombre, moneda, incluye_igv) values
  ('GEN', 'LISTA GENERAL', 'PEN', true),
  ('IMP', 'IMPORTACION',   'USD', true);

-- ------------------------------------------------------------
-- COMMERCIAL INVOICE CI:001-0000070
-- Compra de importación, USD, T.C. 3.500, precios con IGV.
-- Monto neto 80,861.12 + IGV 14,555.00 = 95,416.12.
-- ------------------------------------------------------------

with doc as (
  insert into documentos (
    tipo_documento, serie, correlativo, sucursal_id, almacen_id,
    proveedor_id, vendedor_id, fecha_emision, fecha_almacen,
    condicion_pago_id, forma_pago, moneda, tipo_cambio,
    precios_incluyen_igv, modo_descuento,
    lista_precio_id, referencia_externa, estado
  )
  select
    'CI', '001', 70,
    (select id from sucursales where codigo = 'M'),
    (select id from almacenes where codigo = 'VIC'),
    (select id from proveedores where razon_social like 'NINGBO%'),
    (select id from vendedores where codigo = 'V002'),
    date '2026-01-05', date '2026-01-05',
    (select id from condiciones_pago where codigo = 'COMPRA'),
    'CONTADO', 'USD', 3.5000,
    true, 'SUCESIVO',
    (select id from listas_precio where codigo = 'IMP'),
    'INVOICE: 2025C130', 'BORRADOR'
  returning id
)
insert into documento_lineas (
  documento_id, numero_linea, producto_id, presentacion_id, sku,
  descripcion, unidad_medida, cantidad, factor_conversion,
  precio_unitario, afectacion_igv, tasa_igv
)
select
  doc.id, v.n, p.id, pr.id, p.sku,
  p.descripcion || ' X ' || pr.factor::int || 'UND',
  pr.unidad_medida, v.cantidad, pr.factor,
  v.precio, '10', 0.18
from doc
join (values
  (1, '004847', 'CAJA72', 186.0, 22.0894),
  (2, '004848', 'CAJA48', 200.0, 20.0412),
  (3, '004848', 'CAJA72', 582.0, 28.4937),
  (4, '004849', 'CAJA48', 400.0, 20.0127),
  (5, '004849', 'CAJA72', 990.0, 28.4652),
  (6, '005261', 'CAJA72', 100.0, 29.9890),
  (7, '009040', 'CAJA72', 200.0, 28.9753),
  (8, '004845', 'CAJA36', 994.0, 20.7327),
  (9, '004844', 'CAJA36', 240.0, 21.3667)
) as v(n, sku, presentacion, cantidad, precio) on true
join productos p on p.sku = v.sku
join presentaciones pr on pr.producto_id = p.id and pr.codigo = v.presentacion;

-- Comprobación: tras confirmar este documento, el importe_total
-- debe quedar en 95,416.09 (la diferencia de 3 céntimos con el
-- 95,416.12 impreso viene de que el sistema antiguo redondea el
-- neto y no las líneas).
--
--   select serie, correlativo, importe_total, total_igv
--     from documentos where tipo_documento = 'CI';
--
-- Y el stock queda en unidades, no en cajas:
--   186 x 72 = 13,392 unidades del P8H-RT
--   (200 x 48) + (582 x 72) = 51,504 unidades del P9H-RH
--
--   select p.sku, p.modelo, s.cantidad
--     from stock_actual s join productos p on p.id = s.producto_id;
