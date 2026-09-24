-- ============================================================
-- 003_productos.sql
-- Familias, productos con atributos estructurados, presentaciones
-- (el "X 72UND" que en el sistema antiguo vivía dentro del texto)
-- y listas de precios.
-- ============================================================

-- ------------------------------------------------------------
-- FAMILIAS
-- ------------------------------------------------------------

create table familias (
  id uuid primary key default gen_random_uuid(),
  codigo text unique not null,
  nombre text not null,                       -- 'PLATO MORELLA HOTELERO'
  familia_padre_id uuid references familias(id),
  activo boolean not null default true
);

-- ------------------------------------------------------------
-- PRODUCTOS
--
-- El sistema antiguo guarda todo esto dentro de la descripción:
--   "PLATO MORELLA #9 HOTELERO HONDO REDONDO P9H-RH X 48UND"
-- Aquí cada dato es una columna y la descripción se genera.
-- Así se puede filtrar por tamaño, agrupar por modelo y cambiar
-- el texto comercial sin romper nada.
-- ------------------------------------------------------------

create type forma_producto as enum ('REDONDO', 'CUADRADO', 'OVALADO', 'RECTANGULAR', 'OTRO');
create type perfil_producto as enum ('HONDO', 'TENDIDO', 'PLANO', 'OTRO');

-- Postgres marca enum_out (el cast enum -> text) como STABLE porque
-- resuelve la etiqueta contra pg_enum. Una columna generada exige
-- IMMUTABLE, así que envolvemos el cast para poder usarlo en 'descripcion'.
create function enum_a_texto(anyenum)
returns text
language sql
immutable
as $$ select $1::text $$;

create table productos (
  id uuid primary key default gen_random_uuid(),
  sku text unique not null,                   -- '004848'
  familia_id uuid references familias(id),

  -- Atributos que antes vivían en el texto
  modelo text,                                -- 'P9H-RH'
  tamano numeric(4,1),                        -- 9.0, 9.5, 10.5
  forma forma_producto,
  perfil perfil_producto,
  linea text,                                 -- 'HOTELERO'
  marca text,                                 -- 'MORELLA'

  -- Descripción generada. No se escribe a mano.
  descripcion text generated always as (
    trim(both ' ' from
      coalesce('PLATO ' || marca, '') ||
      coalesce(' #' || trim(trailing '.' from trim(trailing '0' from tamano::text)), '') ||
      coalesce(' ' || linea, '') ||
      coalesce(' ' || enum_a_texto(perfil), '') ||
      coalesce(' ' || enum_a_texto(forma), '') ||
      coalesce(' ' || modelo, '')
    )
  ) stored,
  descripcion_comercial text,                 -- override manual opcional

  -- Unidad base: todo el stock se lleva aquí, siempre
  unidad_base text not null default 'NIU' references cat_unidad_medida(codigo),

  -- Fiscal
  afectacion_igv text not null default '10' references cat_afectacion_igv(codigo),
  -- UNSPSC de 8 dígitos, Catálogo 25. Desde el 1 de enero de 2027
  -- un código inválido o ausente hace que SUNAT rechace el
  -- comprobante con el error 3496. Hasta entonces es observación.
  codigo_producto_sunat text check (codigo_producto_sunat ~ '^[0-9]{8}$'),
  sujeto_percepcion boolean not null default false,
  tasa_percepcion numeric(5,4) not null default 0,
  sujeto_detraccion boolean not null default false,
  codigo_detraccion text,
  tasa_detraccion numeric(5,4) not null default 0,

  -- Inventario y coste
  coste_medio numeric(14,4) not null default 0,   -- ponderado móvil, en moneda base
  stock_minimo numeric(14,3) not null default 0,
  controla_stock boolean not null default true,

  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  creado_por uuid references profiles(id)
);

create index productos_familia_idx on productos (familia_id) where activo;
create index productos_modelo_idx on productos (modelo) where activo;
create index productos_tamano_idx on productos (tamano) where activo;

-- ------------------------------------------------------------
-- PRESENTACIONES
--
-- Esto resuelve el problema de los SKU duplicados de la captura:
--   004848 -> P9H-RH X 48UND
--   005548 -> P9H-RH X 72UND   (enlazados por Cod.Anexo)
-- Es el mismo plato en dos empaques. Con presentaciones hay UN
-- producto, UN stock en unidad base, y dos formas de comprarlo
-- y venderlo.
-- ------------------------------------------------------------

create table presentaciones (
  id uuid primary key default gen_random_uuid(),
  producto_id uuid not null references productos(id) on delete cascade,
  codigo text not null,                       -- 'CAJA72', 'CAJA48', 'UND'
  nombre text not null,                       -- 'CAJA X 72 UND'
  unidad_medida text not null references cat_unidad_medida(codigo),
  factor numeric(14,6) not null check (factor > 0),  -- unidades base por presentación
  es_base boolean not null default false,
  es_default_venta boolean not null default false,
  es_default_compra boolean not null default false,
  -- SKU heredado del sistema antiguo, si existía uno por empaque.
  -- Permite importar los datos históricos sin perder la referencia.
  sku_legacy text,
  activo boolean not null default true,
  unique (producto_id, codigo)
);

create unique index presentaciones_una_base
  on presentaciones (producto_id) where es_base;
create unique index presentaciones_un_default_venta
  on presentaciones (producto_id) where es_default_venta;
create unique index presentaciones_sku_legacy_uk
  on presentaciones (sku_legacy) where sku_legacy is not null;

-- ------------------------------------------------------------
-- LISTAS DE PRECIOS
--
-- Precio en numeric(14,4): la factura de la captura muestra 22.08
-- en pantalla pero el valor real es 22.0894. Con dos decimales,
-- 186 cajas ya se desvían más de un dólar.
--
-- incluye_igv a nivel de lista: el sistema antiguo trabaja con
-- "Precio Neto (Incl. Impstos)".
-- ------------------------------------------------------------

create table listas_precio (
  id uuid primary key default gen_random_uuid(),
  codigo text unique not null,
  nombre text not null,
  moneda text not null references monedas(codigo),
  incluye_igv boolean not null default true,
  activo boolean not null default true
);

create table precios (
  id uuid primary key default gen_random_uuid(),
  lista_id uuid not null references listas_precio(id) on delete cascade,
  producto_id uuid not null references productos(id) on delete cascade,
  presentacion_id uuid references presentaciones(id),
  precio numeric(14,4) not null check (precio >= 0),
  cantidad_minima numeric(14,3) not null default 0,   -- escalado por volumen
  vigente_desde date not null default current_date,
  vigente_hasta date,
  unique (lista_id, producto_id, presentacion_id, cantidad_minima, vigente_desde)
);

create index precios_lookup_idx
  on precios (producto_id, lista_id, vigente_desde desc);
