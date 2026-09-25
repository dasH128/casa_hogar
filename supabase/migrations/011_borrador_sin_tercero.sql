-- ============================================================
-- 011_borrador_sin_tercero.sql
-- /ventas/nueva crea el BORRADOR antes de que el usuario elija
-- cliente (ver `VentaDraftNotifier._crearBorrador`), y el cliente se
-- asigna después con un UPDATE. El check `doc_tercero_requerido` de
-- 004 lo exigía ya en el INSERT, así que la pantalla fallaba al abrir.
--
-- El tercero pasa a ser obligatorio solo cuando el documento sale de
-- BORRADOR. El trigger da un mensaje legible al confirmar; el check
-- queda como red de seguridad para cualquier otro camino.
-- ============================================================

alter table documentos drop constraint doc_tercero_requerido;

alter table documentos add constraint doc_tercero_requerido check (
  estado = 'BORRADOR' or cliente_id is not null or proveedor_id is not null
);

create or replace function app.validar_tercero_documento()
returns trigger
language plpgsql
as $$
begin
  if new.estado <> 'BORRADOR'
     and new.cliente_id is null
     and new.proveedor_id is null then
    raise exception 'El documento no tiene cliente ni proveedor';
  end if;
  return new;
end;
$$;

create trigger documentos_validar_tercero
  before insert or update of estado, cliente_id, proveedor_id on documentos
  for each row execute function app.validar_tercero_documento();
