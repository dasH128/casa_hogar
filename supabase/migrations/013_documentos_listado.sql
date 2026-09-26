-- ============================================================
-- 013_documentos_listado.sql
-- Datos de la pantalla Documentos (ver docs/ui-spec.md, pantalla
-- "3. Documentos").
--
-- El estado del documento y el estado ante SUNAT son dos columnas
-- distintas a propósito: una nota de salida está emitida y jamás
-- tendrá CDR; una factura puede estar emitida y rechazada a la vez.
-- `estado` sale de documentos, `estado_sunat` de cpe_envios.
-- ============================================================

create view documentos_listado
with (security_invoker = true)
as
select
  d.id,
  d.tipo_documento,
  t.es_fiscal,
  t.es_compra,
  -- SUNAT exige ocho dígitos de correlativo en comprobantes; los
  -- documentos internos conservan los siete del sistema antiguo.
  case when d.correlativo is null then null
       else d.serie || '-' || lpad(d.correlativo::text,
                                   case when t.es_fiscal then 8 else 7 end, '0')
  end as numero,
  d.fecha_emision,
  d.estado,
  d.moneda,
  m.simbolo as simbolo_moneda,
  -- Una nota de crédito resta: se muestra con signo negativo.
  case when d.tipo_documento = 'NC' then -d.importe_total
       else d.importe_total
  end as importe,
  coalesce(c.razon_social, p.razon_social) as tercero,
  coalesce(c.tipo_doc_identidad, p.tipo_doc_identidad) as tercero_tipo_doc,
  coalesce(c.numero_documento, p.numero_documento) as tercero_numero_doc,
  ref.serie || '-' || lpad(ref.correlativo::text, 8, '0') as referencia_numero,
  d.motivo_nota,
  nc.serie || '-' || lpad(nc.correlativo::text, 8, '0') as nota_credito_numero,
  case
    when not t.es_fiscal then 'NO_FISCAL'
    when e.estado is null then 'SIN_ENVIO'
    -- Las boletas van a SUNAT en el resumen diario, no una a una.
    when d.tipo_documento = 'BV' and e.estado in ('PENDIENTE','ENVIANDO')
      then 'RESUMEN_DIARIO'
    when e.estado in ('PENDIENTE','ENVIANDO') then 'PENDIENTE'
    else e.estado::text
  end as estado_sunat,
  e.codigo_respuesta,
  e.descripcion_respuesta,
  e.respondido_en,
  -- Plazo legal: hasta 3 días calendario posteriores a la emisión
  -- (R.S. 003-2023/SUNAT, ver 004). Negativo si ya venció.
  (d.fecha_emision + 3) - current_date as dias_plazo_envio
from documentos d
join tipos_documento t on t.codigo = d.tipo_documento
join monedas m on m.codigo = d.moneda
left join clientes c on c.id = d.cliente_id
left join proveedores p on p.id = d.proveedor_id
left join documentos ref on ref.id = d.documento_referencia_id
left join lateral (
  select n.serie, n.correlativo
    from documentos n
   where n.documento_referencia_id = d.id
     and n.tipo_documento = 'NC'
     and n.estado <> 'BORRADOR'
   order by n.fecha_emision
   limit 1
) nc on true
left join lateral (
  select x.estado, x.codigo_respuesta, x.descripcion_respuesta, x.respondido_en
    from cpe_envios x
   where x.documento_id = d.id
   order by x.proximo_intento_en desc
   limit 1
) e on true;

grant select on documentos_listado to authenticated;

create index if not exists documentos_referencia_idx
  on documentos (documento_referencia_id)
  where documento_referencia_id is not null;

-- ------------------------------------------------------------
-- TARJETAS DE RESUMEN
-- No dependen de los filtros de la tabla: son el estado del día.
-- ------------------------------------------------------------

create or replace function resumen_documentos()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'aceptados_hoy', count(*) filter (
      where estado_sunat = 'ACEPTADO' and respondido_en::date = current_date),
    'pendientes_envio', count(*) filter (
      where estado_sunat in ('PENDIENTE','ERROR_TECNICO')),
    'rechazados', count(*) filter (
      where estado_sunat = 'RECHAZADO' and estado <> 'ANULADO')
  )
  from documentos_listado;
$$;

revoke all on function resumen_documentos() from public;
grant execute on function resumen_documentos() to authenticated;
