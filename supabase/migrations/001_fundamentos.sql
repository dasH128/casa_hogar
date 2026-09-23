-- ============================================================
-- 001_fundamentos.sql
-- Extensiones, esquema interno, enums, catálogos SUNAT,
-- identidad, roles y permisos.
-- ============================================================

create extension if not exists pgcrypto;

-- Esquema privado para funciones internas.
-- PostgREST no lo expone, así que nada de aquí es llamable desde Flutter.
create schema if not exists app;

-- ------------------------------------------------------------
-- ENUMS
-- ------------------------------------------------------------

create type estado_documento as enum (
  'BORRADOR',    -- editable, no mueve stock
  'EMITIDO',     -- confirmado, ya movió stock, correlativo asignado
  'ENVIANDO',    -- en cola hacia el PSE/OSE
  'ACEPTADO',    -- CDR conforme
  'OBSERVADO',   -- CDR con observaciones
  'RECHAZADO',   -- CDR de rechazo: hay que corregir y reemitir
  'ANULADO'      -- baja o nota de crédito total aplicada
);

create type forma_pago as enum ('CONTADO', 'CREDITO');

create type modo_descuento as enum ('SUCESIVO', 'LINEAL');

create type tipo_movimiento as enum (
  'ENTRADA', 'SALIDA', 'AJUSTE_POSITIVO', 'AJUSTE_NEGATIVO',
  'TRANSFERENCIA_ENTRADA', 'TRANSFERENCIA_SALIDA'
);

create type estado_envio_cpe as enum (
  'PENDIENTE', 'ENVIANDO', 'ACEPTADO', 'OBSERVADO',
  'RECHAZADO', 'BAJA_SOLICITADA', 'BAJA_ACEPTADA', 'ERROR_TECNICO'
);

-- ------------------------------------------------------------
-- CATÁLOGOS SUNAT
--
-- IMPORTANTE: estas semillas cubren los códigos de uso habitual.
-- SUNAT actualiza los catálogos varias veces al año, así que antes
-- de producción hay que descargarlos completos desde cpe.sunat.gob.pe
-- y cargarlos aquí. Están como tablas y no como enums precisamente
-- para poder actualizarlos sin migración.
-- ------------------------------------------------------------

-- Catálogo 01: tipo de comprobante
create table cat_tipo_comprobante (
  codigo text primary key,
  nombre text not null
);

insert into cat_tipo_comprobante (codigo, nombre) values
  ('01', 'Factura'),
  ('03', 'Boleta de venta'),
  ('07', 'Nota de crédito'),
  ('08', 'Nota de débito'),
  ('09', 'Guía de remisión remitente');

-- Catálogo 06: tipo de documento de identidad del adquirente
create table cat_tipo_doc_identidad (
  codigo text primary key,
  nombre text not null,
  longitud int,
  patron text                 -- regex de validación
);

insert into cat_tipo_doc_identidad (codigo, nombre, longitud, patron) values
  ('0', 'Doc. trib. no domiciliado sin RUC', null, null),
  ('1', 'DNI',                    8,  '^[0-9]{8}$'),
  ('4', 'Carnet de extranjería',  12, '^[A-Za-z0-9]{1,12}$'),
  ('6', 'RUC',                    11, '^[0-9]{11}$'),
  ('7', 'Pasaporte',              12, '^[A-Za-z0-9]{1,12}$'),
  ('A', 'Cédula diplomática',     15, null);

-- Catálogo 07: tipo de afectación del IGV
create table cat_afectacion_igv (
  codigo text primary key,
  nombre text not null,
  grupo text not null,        -- GRAVADO | EXONERADO | INAFECTO | EXPORTACION | GRATUITO
  tasa_igv numeric(5,4) not null default 0
);

insert into cat_afectacion_igv (codigo, nombre, grupo, tasa_igv) values
  ('10', 'Gravado - operación onerosa',    'GRAVADO',     0.18),
  ('20', 'Exonerado - operación onerosa',  'EXONERADO',   0.00),
  ('30', 'Inafecto - operación onerosa',   'INAFECTO',    0.00),
  ('40', 'Exportación de bienes/servicios','EXPORTACION', 0.00),
  ('11', 'Gravado - retiro por bonificación','GRATUITO',  0.18),
  ('21', 'Exonerado - transferencia gratuita','GRATUITO', 0.00),
  ('31', 'Inafecto - retiro por bonificación','GRATUITO', 0.00);

-- Catálogo 03: unidad de medida (UN/ECE rec. 20)
create table cat_unidad_medida (
  codigo text primary key,
  nombre text not null
);

insert into cat_unidad_medida (codigo, nombre) values
  ('NIU', 'Unidad (bienes)'),
  ('ZZ',  'Unidad (servicios)'),
  ('BX',  'Caja'),
  ('PK',  'Paquete'),
  ('KGM', 'Kilogramo'),
  ('MTR', 'Metro'),
  ('LTR', 'Litro'),
  ('SET', 'Juego');

-- Catálogo 09: motivos de nota de crédito
create table cat_motivo_nc (
  codigo text primary key,
  nombre text not null,
  altera_importe boolean not null default true
);

insert into cat_motivo_nc (codigo, nombre, altera_importe) values
  ('01', 'Anulación de la operación', true),
  ('02', 'Anulación por error en el RUC', true),
  -- Motivo 03 redefinido por SUNAT en 2026: corrige descripción o
  -- código de producto SUNAT sin alterar el importe de la operación.
  ('03', 'Corrección de descripción o código de producto', false),
  ('04', 'Descuento global', true),
  ('05', 'Descuento por ítem', true),
  ('06', 'Devolución total', true),
  ('07', 'Devolución por ítem', true),
  ('08', 'Bonificación', true),
  ('09', 'Disminución en el valor', true),
  ('10', 'Otros conceptos', true);

-- Catálogo 10: motivos de nota de débito
create table cat_motivo_nd (
  codigo text primary key,
  nombre text not null
);

insert into cat_motivo_nd (codigo, nombre) values
  ('01', 'Intereses por mora'),
  ('02', 'Aumento en el valor'),
  ('03', 'Penalidades u otros conceptos'),
  -- Motivo incorporado por SUNAT desde agosto de 2026.
  ('13', 'Penalidades en operaciones inafectas');

-- Monedas
create table monedas (
  codigo text primary key,           -- ISO 4217
  nombre text not null,
  simbolo text not null
);

insert into monedas (codigo, nombre, simbolo) values
  ('PEN', 'Soles',   'S/'),
  ('USD', 'Dólares', 'US$'),
  ('EUR', 'Euros',   '€');

-- Tipos de documento interno.
-- Aquí conviven los documentos fiscales (NOTA DE SALIDA que factura,
-- factura, boleta) y los puramente internos (commercial invoice de
-- importación, orden de compra). La diferencia está en es_fiscal.
create table tipos_documento (
  codigo text primary key,           -- NS, CI, FT, BV, NC, ND, OC
  nombre text not null,
  es_fiscal boolean not null default false,
  tipo_comprobante_sunat text references cat_tipo_comprobante(codigo),
  afecta_stock boolean not null default false,
  signo_stock smallint not null default 0 check (signo_stock in (-1, 0, 1)),
  afecta_cuenta_corriente boolean not null default false,
  es_compra boolean not null default false,
  activo boolean not null default true
);

insert into tipos_documento
  (codigo, nombre, es_fiscal, tipo_comprobante_sunat, afecta_stock, signo_stock, afecta_cuenta_corriente, es_compra) values
  ('NS', 'Nota de salida',    false, null, true,  -1, true,  false),
  ('NI', 'Nota de ingreso',   false, null, true,   1, false, true),
  ('CI', 'Commercial invoice',false, null, true,   1, true,  true),
  ('FT', 'Factura',           true,  '01', true,  -1, true,  false),
  ('BV', 'Boleta de venta',   true,  '03', true,  -1, true,  false),
  ('NC', 'Nota de crédito',   true,  '07', false,  0, true,  false),
  ('ND', 'Nota de débito',    true,  '08', false,  0, true,  false),
  ('OC', 'Orden de compra',   false, null, false,  0, false, true);

-- ------------------------------------------------------------
-- IDENTIDAD, ROLES Y PERMISOS
-- ------------------------------------------------------------

create table roles (
  id uuid primary key default gen_random_uuid(),
  codigo text unique not null,
  nombre text not null
);

insert into roles (codigo, nombre) values
  ('admin',    'Administrador'),
  ('gerente',  'Gerente'),
  ('vendedor', 'Vendedor'),
  ('almacen',  'Almacén'),
  ('lectura',  'Solo lectura');

-- Permisos en tabla, no en el texto de las políticas.
-- Cambiar quién puede hacer qué es un INSERT, no una migración.
create table permisos (
  rol_id uuid not null references roles(id) on delete cascade,
  recurso text not null,             -- ventas, compras, productos, stock, informes, usuarios
  accion text not null,              -- read, create, update, delete, confirm, cancel
  primary key (rol_id, recurso, accion)
);

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text not null,
  rol_id uuid not null references roles(id),
  sucursal_id uuid,                  -- FK añadida en 003
  vendedor_id uuid,                  -- FK añadida en 003
  activo boolean not null default true,
  creado_en timestamptz not null default now()
);

-- Crear el perfil automáticamente al registrarse.
-- Por defecto entra como 'lectura'; un admin lo promueve después.
create or replace function app.crear_perfil_nuevo_usuario()
returns trigger
language plpgsql
security definer
set search_path = public, app
as $$
begin
  insert into public.profiles (id, nombre, rol_id)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nombre', split_part(new.email, '@', 1)),
    (select id from public.roles where codigo = 'lectura')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function app.crear_perfil_nuevo_usuario();

-- ------------------------------------------------------------
-- HELPERS DE PERMISOS (usados por las políticas RLS en 006)
-- ------------------------------------------------------------

-- Lee el rol del claim del JWT si el Custom Access Token Hook lo
-- inyecta; si no, cae al perfil. El claim evita una consulta por fila.
-- Ojo: los claims se refrescan cada hora, así que un cambio de rol
-- no es inmediato. Para efecto inmediato hay que forzar logout.
create or replace function app.rol_actual()
returns text
language sql
stable
security definer
set search_path = public, app
as $$
  select coalesce(
    nullif(current_setting('request.jwt.claims', true)::jsonb ->> 'user_rol', ''),
    (select r.codigo
       from public.profiles p
       join public.roles r on r.id = p.rol_id
      where p.id = auth.uid()
        and p.activo)
  );
$$;

create or replace function app.tiene_permiso(p_recurso text, p_accion text)
returns boolean
language sql
stable
security definer
set search_path = public, app
as $$
  select exists (
    select 1
      from public.permisos pm
      join public.roles r on r.id = pm.rol_id
     where r.codigo = app.rol_actual()
       and pm.recurso = p_recurso
       and pm.accion  = p_accion
  );
$$;

create or replace function app.es_admin()
returns boolean
language sql
stable
as $$ select app.rol_actual() = 'admin'; $$;
