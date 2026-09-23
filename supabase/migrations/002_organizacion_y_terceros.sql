-- ============================================================
-- 002_organizacion_y_terceros.sql
-- Sucursales, almacenes, vendedores, zonas, condiciones de pago,
-- transportes, clientes y proveedores.
-- ============================================================

-- ------------------------------------------------------------
-- ORGANIZACIÓN
-- El sistema antiguo muestra Sucursal y Almacén como campos
-- separados en cabecera. Se mantiene: una sucursal puede tener
-- varios almacenes, y las series de comprobante cuelgan de la
-- sucursal (SUNAT las asocia al establecimiento anexo).
-- ------------------------------------------------------------

create table sucursales (
  id uuid primary key default gen_random_uuid(),
  codigo text unique not null,              -- 'M'
  nombre text not null,                      -- 'DISTRIBUIDORA MORELLA'
  codigo_establecimiento_sunat text,         -- '0000' para el domicilio fiscal
  direccion text,
  ubigeo text,
  activo boolean not null default true
);

create table almacenes (
  id uuid primary key default gen_random_uuid(),
  sucursal_id uuid not null references sucursales(id),
  codigo text not null,
  nombre text not null,                      -- 'MORELLA - VICTORIA'
  direccion text,
  activo boolean not null default true,
  unique (sucursal_id, codigo)
);

create table zonas (
  id uuid primary key default gen_random_uuid(),
  codigo text unique not null,
  nombre text not null,
  activo boolean not null default true
);

create table vendedores (
  id uuid primary key default gen_random_uuid(),
  codigo text unique not null,
  nombre text not null,                      -- 'ANGELA'
  profile_id uuid references profiles(id),   -- opcional: si además usa el sistema
  comision_pct numeric(7,4) not null default 0,
  activo boolean not null default true
);

alter table profiles
  add constraint profiles_sucursal_fk
    foreign key (sucursal_id) references sucursales(id),
  add constraint profiles_vendedor_fk
    foreign key (vendedor_id) references vendedores(id);

create table transportes (
  id uuid primary key default gen_random_uuid(),
  codigo text unique not null,
  nombre text not null,                      -- '[NINGUNO]'
  ruc text,
  activo boolean not null default true
);

-- ------------------------------------------------------------
-- CONDICIONES DE PAGO
-- En el sistema antiguo 'CHQ DIFERIDO 15 DIAS' es un catálogo con
-- días asociados: emisión 03/08 + 15 = vencimiento 18/08.
-- Con cuotas_json se soportan planes de varias cuotas, que es lo
-- que exige SUNAT cuando la forma de pago es crédito.
-- ------------------------------------------------------------

create table condiciones_pago (
  id uuid primary key default gen_random_uuid(),
  codigo text unique not null,
  nombre text not null,                      -- 'CHQ DIFERIDO 15 DIAS'
  forma_pago forma_pago not null,
  dias_credito int not null default 0,
  -- Plan de cuotas: [{"dias": 30, "pct": 50}, {"dias": 60, "pct": 50}]
  -- Vacío significa una sola cuota a dias_credito.
  cuotas_json jsonb not null default '[]'::jsonb,
  activo boolean not null default true,
  constraint cond_pago_contado_sin_dias
    check (forma_pago = 'CREDITO' or dias_credito = 0)
);

-- ------------------------------------------------------------
-- TERCEROS
--
-- Cambio respecto a un modelo genérico: el identificador NO es un
-- campo libre. Es (tipo_doc del catálogo 06, número), porque de ahí
-- depende qué comprobante se puede emitir. En la captura el cliente
-- AYDEE QUICO HANCCO tiene DNI y el campo RUC vacío: es persona
-- natural, le corresponde boleta, no factura.
-- ------------------------------------------------------------

create table clientes (
  id uuid primary key default gen_random_uuid(),
  tipo_doc_identidad text not null references cat_tipo_doc_identidad(codigo),
  numero_documento text not null,
  razon_social text not null,
  nombre_comercial text,
  direccion text,
  ubigeo text,
  email text,
  telefono text,
  zona_id uuid references zonas(id),
  vendedor_id uuid references vendedores(id),
  condicion_pago_id uuid references condiciones_pago(id),
  -- Control de crédito: el panel lateral de la captura muestra
  -- 'Limite Credito' por razón social.
  limite_credito numeric(14,2) not null default 0,
  moneda_credito text not null default 'PEN' references monedas(codigo),
  bloqueado boolean not null default false,
  motivo_bloqueo text,
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  unique (tipo_doc_identidad, numero_documento)
);

-- Valida el número contra el patrón del catálogo 06.
create or replace function app.validar_doc_identidad()
returns trigger
language plpgsql
as $$
declare
  v_patron text;
begin
  select patron into v_patron
    from public.cat_tipo_doc_identidad
   where codigo = new.tipo_doc_identidad;

  if v_patron is not null and new.numero_documento !~ v_patron then
    raise exception 'El número % no cumple el formato del tipo de documento %',
      new.numero_documento, new.tipo_doc_identidad;
  end if;
  return new;
end;
$$;

create trigger clientes_valida_doc
  before insert or update of tipo_doc_identidad, numero_documento on clientes
  for each row execute function app.validar_doc_identidad();

create table proveedores (
  id uuid primary key default gen_random_uuid(),
  tipo_doc_identidad text not null references cat_tipo_doc_identidad(codigo),
  numero_documento text,                     -- nulo para no domiciliados
  razon_social text not null,                -- 'NINGBO YUN RUI TRADING CO. LTD'
  es_no_domiciliado boolean not null default false,
  pais text,
  direccion text,
  email text,
  telefono text,
  moneda_habitual text not null default 'PEN' references monedas(codigo),
  condicion_pago_id uuid references condiciones_pago(id),
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

create unique index proveedores_doc_uk
  on proveedores (tipo_doc_identidad, numero_documento)
  where numero_documento is not null;

create index clientes_razon_social_idx on clientes using gin (to_tsvector('simple', razon_social));
create index clientes_zona_idx on clientes (zona_id) where activo;
