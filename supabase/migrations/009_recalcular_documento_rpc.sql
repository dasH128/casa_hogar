-- ============================================================
-- 009_recalcular_documento_rpc.sql
-- Wrapper público para app.recalcular_totales().
--
-- PostgREST no expone el schema `app` (ver 001_fundamentos.sql).
-- confirmar_documento() ya llama a recalcular_totales() por dentro,
-- pero la pantalla de venta necesita recalcular en cada cambio de
-- línea mientras el documento sigue en BORRADOR, antes de confirmar.
-- Este wrapper es ese mismo cálculo, sin cambiar de estado.
-- ============================================================

create or replace function recalcular_documento(p_documento_id uuid)
returns documentos
language plpgsql
security definer
set search_path = public, app
as $$
declare
  d documentos;
begin
  select * into d from documentos where id = p_documento_id;
  if not found then
    raise exception 'Documento % inexistente', p_documento_id;
  end if;
  if not app.tiene_permiso(app.recurso_de(d.tipo_documento), 'update') then
    raise exception 'Sin permiso para editar este documento';
  end if;

  perform app.recalcular_totales(p_documento_id);

  return (select * from documentos where id = p_documento_id);
end;
$$;

revoke all on function recalcular_documento(uuid) from public;
grant execute on function recalcular_documento(uuid) to authenticated;
