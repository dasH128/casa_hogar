-- ============================================================
-- 012_ficha_cliente.sql
-- Datos de la ficha de cliente (ver docs/ui-spec.md, pantalla
-- "6. Ficha de cliente"). Todo importe, saldo o conteo sale de aquí:
-- la pantalla solo pinta lo que devuelve la base de datos.
--
-- Los estados vigentes son los mismos que usa confirmar_documento()
-- para el control de crédito (005), para que el "Usado" de la ficha
-- y el aviso al confirmar una venta den siempre el mismo número.
-- ============================================================

-- ------------------------------------------------------------
-- CUENTA CORRIENTE
-- Una fila por cuota, no por documento: una factura a dos cuotas
-- ocupa dos filas. security_invoker hace que se apliquen las RLS de
-- documentos, documento_cuotas y clientes del usuario que consulta.
-- ------------------------------------------------------------

create view cuenta_corriente_cuotas
with (security_invoker = true)
as
select
  c.id as cuota_id,
  d.cliente_id,
  d.id as documento_id,
  d.tipo_documento,
  d.serie,
  d.correlativo,
  d.fecha_emision,
  d.moneda,
  c.numero,
  count(*) over (partition by d.id) as total_cuotas,
  c.fecha_vencimiento,
  c.monto,
  c.monto - c.monto_pagado as saldo,
  case
    when c.monto - c.monto_pagado <= 0 then 'CANCELADA'
    when c.fecha_vencimiento < current_date then 'VENCIDA'
    else 'POR_VENCER'
  end as estado_cuota,
  greatest(current_date - c.fecha_vencimiento, 0) as dias_atraso
from documento_cuotas c
join documentos d on d.id = c.documento_id
where d.cliente_id is not null
  and d.estado in ('EMITIDO','ENVIANDO','ACEPTADO','OBSERVADO');

grant select on cuenta_corriente_cuotas to authenticated;

-- ------------------------------------------------------------
-- RESUMEN DE CRÉDITO Y ACTIVIDAD
-- limite_credito = 0 significa "sin límite": es como lo trata
-- confirmar_documento() (solo controla cuando v_limite > 0).
-- pct_usado va entero de 0 a 100 para la barra de crédito, así la
-- interfaz no tiene que dividir importes.
-- ------------------------------------------------------------

create or replace function resumen_cliente(p_cliente_id uuid)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  with cliente as (
    select limite_credito, moneda_credito
      from clientes
     where id = p_cliente_id
  ),
  deuda as (
    select coalesce(sum(saldo_pendiente), 0) as usado
      from documentos
     where cliente_id = p_cliente_id
       and estado in ('EMITIDO','ENVIANDO','ACEPTADO','OBSERVADO')
  ),
  vencidas as (
    select count(*) as cuotas,
           coalesce(sum(saldo), 0) as importe,
           coalesce(max(dias_atraso), 0) as dias_atraso
      from cuenta_corriente_cuotas
     where cliente_id = p_cliente_id
       and estado_cuota = 'VENCIDA'
  ),
  ventas_12m as (
    select count(*) as documentos,
           coalesce(sum(d.importe_total), 0) as facturado
      from documentos d
      join tipos_documento t on t.codigo = d.tipo_documento
     where d.cliente_id = p_cliente_id
       and not t.es_compra
       and d.tipo_documento <> 'NC'
       and d.estado in ('EMITIDO','ENVIANDO','ACEPTADO','OBSERVADO')
       and d.fecha_emision > current_date - interval '12 months'
  )
  select jsonb_build_object(
    'limite_credito', c.limite_credito,
    'moneda_credito', c.moneda_credito,
    'usado', de.usado,
    'disponible', greatest(c.limite_credito - de.usado, 0),
    'pct_usado', case
      when c.limite_credito > 0
        then least(round(de.usado * 100 / c.limite_credito), 100)::int
      else 0
    end,
    'cuotas_vencidas', v.cuotas,
    'importe_vencido', v.importe,
    'dias_atraso', v.dias_atraso,
    'documentos_12m', vt.documentos,
    'facturado_12m', vt.facturado,
    'ticket_medio_12m', case
      when vt.documentos > 0 then round(vt.facturado / vt.documentos, 2)
      else 0
    end
  )
  from cliente c, deuda de, vencidas v, ventas_12m vt;
$$;

revoke all on function resumen_cliente(uuid) from public;
grant execute on function resumen_cliente(uuid) to authenticated;
