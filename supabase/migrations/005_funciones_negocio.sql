-- ============================================================
-- 005_funciones_negocio.sql
-- Toda la aritmética de importes y los cambios de estado viven
-- aquí. Flutter nunca calcula un total ni inserta un movimiento
-- de stock por su cuenta.
-- ============================================================

-- ------------------------------------------------------------
-- RECALCULAR TOTALES
--
-- Un único sitio donde se decide si el precio lleva IGV o no.
-- Si esta lógica se duplica en la app, tarde o temprano una
-- pantalla asume una cosa y otra la contraria.
-- ------------------------------------------------------------

create or replace function app.recalcular_totales(p_documento_id uuid)
returns void
language plpgsql
security definer
set search_path = public, app
as $$
declare
  d record;
  l record;
  v_precio_neto numeric(14,4);
  v_bruto numeric(14,4);
  v_total_linea numeric(14,2);
  v_valor_venta numeric(14,2);
  v_igv numeric(14,2);
  v_percepcion numeric(14,2) := 0;
begin
  select * into d from documentos where id = p_documento_id for update;
  if not found then
    raise exception 'Documento % inexistente', p_documento_id;
  end if;
  if d.estado <> 'BORRADOR' then
    raise exception 'Solo se recalcula un documento en BORRADOR (estado actual: %)', d.estado;
  end if;

  for l in select * from documento_lineas where documento_id = p_documento_id loop

    -- Descuentos sucesivos o lineales, como en el sistema antiguo
    if d.modo_descuento = 'SUCESIVO' then
      v_precio_neto := l.precio_unitario
                       * (1 - l.dto1_pct/100)
                       * (1 - l.dto2_pct/100)
                       * (1 - l.dto3_pct/100);
    else
      v_precio_neto := l.precio_unitario
                       * (1 - (l.dto1_pct + l.dto2_pct + l.dto3_pct)/100);
    end if;

    v_bruto := v_precio_neto * l.cantidad;

    if d.precios_incluyen_igv then
      -- El precio ya trae IGV: se despeja hacia atrás.
      v_total_linea := round(v_bruto, 2);
      v_valor_venta := round(v_bruto / (1 + l.tasa_igv), 2);
      v_igv         := v_total_linea - v_valor_venta;
    else
      v_valor_venta := round(v_bruto, 2);
      v_igv         := round(v_valor_venta * l.tasa_igv, 2);
      v_total_linea := v_valor_venta + v_igv;
    end if;

    update documento_lineas
       set precio_neto        = v_precio_neto,
           descuento_importe  = round((l.precio_unitario - v_precio_neto) * l.cantidad, 2),
           valor_venta        = v_valor_venta,
           igv_linea          = v_igv,
           total_linea        = v_total_linea
     where id = l.id;
  end loop;

  -- Percepción sobre el total, solo para productos marcados
  select coalesce(sum(dl.total_linea * p.tasa_percepcion), 0)
    into v_percepcion
    from documento_lineas dl
    join productos p on p.id = dl.producto_id
   where dl.documento_id = p_documento_id
     and p.sujeto_percepcion;

  update documentos doc
     set total_gravado     = t.gravado,
         total_exonerado   = t.exonerado,
         total_inafecto    = t.inafecto,
         total_exportacion = t.exportacion,
         total_gratuito    = t.gratuito,
         total_descuento   = t.descuento,
         total_igv         = t.igv,
         total_percepcion  = round(v_percepcion, 2),
         importe_total     = t.gravado + t.exonerado + t.inafecto
                             + t.exportacion + t.igv + round(v_percepcion, 2),
         saldo_pendiente   = case when doc.forma_pago = 'CREDITO'
                                  then t.gravado + t.exonerado + t.inafecto
                                       + t.exportacion + t.igv + round(v_percepcion, 2)
                                  else 0 end
    from (
      select
        coalesce(sum(dl.valor_venta) filter (where a.grupo = 'GRAVADO'), 0)     as gravado,
        coalesce(sum(dl.valor_venta) filter (where a.grupo = 'EXONERADO'), 0)   as exonerado,
        coalesce(sum(dl.valor_venta) filter (where a.grupo = 'INAFECTO'), 0)    as inafecto,
        coalesce(sum(dl.valor_venta) filter (where a.grupo = 'EXPORTACION'), 0) as exportacion,
        coalesce(sum(dl.valor_venta) filter (where a.grupo = 'GRATUITO'), 0)    as gratuito,
        coalesce(sum(dl.descuento_importe), 0)                                  as descuento,
        coalesce(sum(dl.igv_linea) filter (where a.grupo <> 'GRATUITO'), 0)     as igv
      from documento_lineas dl
      join cat_afectacion_igv a on a.codigo = dl.afectacion_igv
     where dl.documento_id = p_documento_id
    ) t
   where doc.id = p_documento_id;
end;
$$;

-- ------------------------------------------------------------
-- DISPONIBILIDAD
-- ------------------------------------------------------------

create or replace function app.stock_disponible(p_almacen_id uuid, p_producto_id uuid)
returns numeric
language sql
stable
as $$
  select coalesce(sum(cantidad_base * signo), 0)
    from public.movimientos_stock
   where almacen_id = p_almacen_id
     and producto_id = p_producto_id;
$$;

-- ------------------------------------------------------------
-- CONFIRMAR DOCUMENTO
--
-- Atómico: valida stock y crédito, asigna correlativo, genera
-- movimientos, recalcula coste medio en compras, cambia estado y
-- encola el envío si el documento es fiscal.
-- Desde Flutter es una sola llamada: supabase.rpc('confirmar_documento').
-- ------------------------------------------------------------

create or replace function confirmar_documento(p_documento_id uuid)
returns documentos
language plpgsql
security definer
set search_path = public, app
as $$
declare
  d documentos;
  td tipos_documento;
  l record;
  v_disponible numeric(14,3);
  v_serie_id uuid;
  v_correlativo bigint;
  v_deuda numeric(14,2);
  v_limite numeric(14,2);
  v_cuota jsonb;
  v_n int := 0;
begin
  if not app.tiene_permiso(
       case when exists (select 1 from tipos_documento t
                          where t.codigo = (select tipo_documento from documentos where id = p_documento_id)
                            and t.es_compra)
            then 'compras' else 'ventas' end,
       'confirm') then
    raise exception 'Sin permiso para confirmar este documento';
  end if;

  select * into d from documentos where id = p_documento_id for update;
  if not found then
    raise exception 'Documento % inexistente', p_documento_id;
  end if;
  if d.estado <> 'BORRADOR' then
    raise exception 'El documento ya fue confirmado (estado: %)', d.estado;
  end if;
  if not exists (select 1 from documento_lineas where documento_id = d.id) then
    raise exception 'El documento no tiene líneas';
  end if;

  select * into td from tipos_documento where codigo = d.tipo_documento;

  perform app.recalcular_totales(d.id);
  select * into d from documentos where id = p_documento_id;

  -- Control de stock (el "No Autorizado para Ventas sin Stock"
  -- del sistema antiguo, aquí como regla dura en el servidor)
  if td.afecta_stock and td.signo_stock = -1 then
    for l in
      select dl.producto_id, dl.descripcion, sum(dl.cantidad_base) as necesita
        from documento_lineas dl
        join productos p on p.id = dl.producto_id
       where dl.documento_id = d.id and p.controla_stock
       group by dl.producto_id, dl.descripcion
    loop
      v_disponible := app.stock_disponible(d.almacen_id, l.producto_id);
      if v_disponible < l.necesita then
        raise exception 'Stock insuficiente de %: disponible %, requerido %',
          l.descripcion, v_disponible, l.necesita;
      end if;
    end loop;
  end if;

  -- Control de límite de crédito
  if d.cliente_id is not null and d.forma_pago = 'CREDITO' then
    select limite_credito into v_limite from clientes where id = d.cliente_id;
    select coalesce(sum(saldo_pendiente), 0) into v_deuda
      from documentos
     where cliente_id = d.cliente_id
       and estado in ('EMITIDO','ENVIANDO','ACEPTADO','OBSERVADO')
       and id <> d.id;
    if v_limite > 0 and (v_deuda + d.importe_total) > v_limite then
      raise exception 'Límite de crédito excedido: deuda %, nuevo total %, límite %',
        v_deuda, d.importe_total, v_limite;
    end if;
  end if;

  -- Correlativo
  select id into v_serie_id
    from series
   where tipo_documento = d.tipo_documento
     and sucursal_id = d.sucursal_id
     and activa
     and (d.serie is null or serie = d.serie)
   order by es_default desc
   limit 1;

  if v_serie_id is null then
    raise exception 'No hay serie activa para % en esta sucursal', d.tipo_documento;
  end if;

  v_correlativo := app.siguiente_correlativo(v_serie_id);

  -- Movimientos de stock
  if td.afecta_stock then
    insert into movimientos_stock
      (almacen_id, producto_id, tipo, signo, cantidad_base,
       coste_unitario, documento_id, documento_linea_id, fecha, creado_por)
    select
      d.almacen_id, dl.producto_id,
      case when td.signo_stock = 1 then 'ENTRADA' else 'SALIDA' end::tipo_movimiento,
      td.signo_stock,
      dl.cantidad_base,
      case when td.signo_stock = 1
           then (dl.valor_venta / nullif(dl.cantidad_base, 0)) * d.tipo_cambio
           else dl.coste_unitario_snapshot end,
      d.id, dl.id,
      coalesce(d.fecha_almacen, d.fecha_emision)::timestamptz,
      auth.uid()
    from documento_lineas dl
    join productos p on p.id = dl.producto_id
    where dl.documento_id = d.id and p.controla_stock;
  end if;

  -- Coste medio ponderado móvil, solo en entradas
  if td.afecta_stock and td.signo_stock = 1 then
    update productos p
       set coste_medio = sub.nuevo_coste
      from (
        select
          dl.producto_id,
          case when (coalesce(sa.cantidad, 0) + sum(dl.cantidad_base)) = 0 then 0
               else (coalesce(sa.cantidad, 0) * max(pr.coste_medio)
                     + sum(dl.valor_venta * d.tipo_cambio))
                    / (coalesce(sa.cantidad, 0) + sum(dl.cantidad_base))
          end as nuevo_coste
        from documento_lineas dl
        join productos pr on pr.id = dl.producto_id
        left join stock_actual sa
               on sa.producto_id = dl.producto_id and sa.almacen_id = d.almacen_id
       where dl.documento_id = d.id
       group by dl.producto_id, sa.cantidad
      ) sub
     where p.id = sub.producto_id;
  end if;

  -- Cuotas a partir de la condición de pago
  if d.forma_pago = 'CREDITO' and d.condicion_pago_id is not null then
    delete from documento_cuotas where documento_id = d.id;
    for v_cuota in
      select * from jsonb_array_elements(
        (select case when cuotas_json = '[]'::jsonb
                     then jsonb_build_array(jsonb_build_object('dias', dias_credito, 'pct', 100))
                     else cuotas_json end
           from condiciones_pago where id = d.condicion_pago_id))
    loop
      v_n := v_n + 1;
      insert into documento_cuotas (documento_id, numero, fecha_vencimiento, monto)
      values (
        d.id, v_n,
        d.fecha_emision + ((v_cuota ->> 'dias')::int),
        round(d.importe_total * (v_cuota ->> 'pct')::numeric / 100, 2)
      );
    end loop;
  end if;

  update documentos
     set serie_id = v_serie_id,
         serie = (select serie from series where id = v_serie_id),
         correlativo = v_correlativo,
         fecha_almacen = coalesce(fecha_almacen, fecha_emision),
         fecha_vencimiento = coalesce(
           fecha_vencimiento,
           (select max(fecha_vencimiento) from documento_cuotas where documento_id = d.id)),
         estado = 'EMITIDO',
         confirmado_por = auth.uid(),
         confirmado_en = now()
   where id = d.id
  returning * into d;

  -- Encolar envío si es comprobante electrónico
  if td.es_fiscal then
    insert into cpe_envios (documento_id, clave_idempotencia)
    values (d.id, d.tipo_documento || '-' || d.serie || '-' || d.correlativo);
  end if;

  return d;
end;
$$;

-- ------------------------------------------------------------
-- ANULAR
--
-- Para documentos internos: movimientos inversos y estado ANULADO.
-- Para comprobantes ya aceptados por SUNAT, esta función se niega:
-- hay que emitir nota de crédito. No se borra nada nunca.
-- ------------------------------------------------------------

create or replace function anular_documento(p_documento_id uuid, p_motivo text)
returns documentos
language plpgsql
security definer
set search_path = public, app
as $$
declare
  d documentos;
  td tipos_documento;
begin
  if not app.tiene_permiso('ventas', 'cancel') then
    raise exception 'Sin permiso para anular documentos';
  end if;
  if p_motivo is null or length(trim(p_motivo)) < 5 then
    raise exception 'Hay que indicar un motivo de anulación';
  end if;

  select * into d from documentos where id = p_documento_id for update;
  select * into td from tipos_documento where codigo = d.tipo_documento;

  if d.estado = 'ANULADO' then
    raise exception 'El documento ya está anulado';
  end if;
  if td.es_fiscal and d.estado in ('ACEPTADO', 'OBSERVADO') then
    raise exception 'Comprobante aceptado por SUNAT: corresponde nota de crédito, no anulación';
  end if;

  if td.afecta_stock then
    insert into movimientos_stock
      (almacen_id, producto_id, tipo, signo, cantidad_base,
       coste_unitario, documento_id, documento_linea_id, fecha, creado_por, nota)
    select
      m.almacen_id, m.producto_id,
      case when m.signo = 1 then 'AJUSTE_NEGATIVO' else 'AJUSTE_POSITIVO' end::tipo_movimiento,
      m.signo * -1, m.cantidad_base, m.coste_unitario,
      m.documento_id, m.documento_linea_id, now(), auth.uid(),
      'Reverso por anulación: ' || p_motivo
    from movimientos_stock m
    where m.documento_id = d.id;
  end if;

  update documentos
     set estado = 'ANULADO',
         saldo_pendiente = 0,
         anulado_por = auth.uid(),
         anulado_en = now(),
         motivo_anulacion = p_motivo
   where id = d.id
  returning * into d;

  return d;
end;
$$;

-- ------------------------------------------------------------
-- NOTA DE CRÉDITO
--
-- Una nota, un documento de referencia. La firma de la función no
-- admite una lista de facturas, precisamente porque SUNAT la
-- rechazaría (error 3261).
-- ------------------------------------------------------------

create or replace function emitir_nota_credito(
  p_documento_ref_id uuid,
  p_motivo_codigo text,
  p_total boolean default true
)
returns documentos
language plpgsql
security definer
set search_path = public, app
as $$
declare
  ref documentos;
  nc_id uuid;
  v_altera boolean;
begin
  if not app.tiene_permiso('ventas', 'cancel') then
    raise exception 'Sin permiso para emitir notas de crédito';
  end if;

  select * into ref from documentos where id = p_documento_ref_id;
  if not found then
    raise exception 'Documento de referencia inexistente';
  end if;
  if ref.estado not in ('EMITIDO','ENVIANDO','ACEPTADO','OBSERVADO') then
    raise exception 'El documento de referencia no admite nota de crédito (estado: %)', ref.estado;
  end if;

  select altera_importe into v_altera from cat_motivo_nc where codigo = p_motivo_codigo;
  if v_altera is null then
    raise exception 'Motivo de nota de crédito % no existe en el catálogo 09', p_motivo_codigo;
  end if;

  insert into documentos (
    tipo_documento, sucursal_id, almacen_id, cliente_id, vendedor_id,
    fecha_emision, moneda, tipo_cambio, precios_incluyen_igv,
    forma_pago, documento_referencia_id, motivo_nota, creado_por
  ) values (
    'NC', ref.sucursal_id, ref.almacen_id, ref.cliente_id, ref.vendedor_id,
    current_date, ref.moneda, ref.tipo_cambio, ref.precios_incluyen_igv,
    'CONTADO', ref.id, p_motivo_codigo, auth.uid()
  ) returning id into nc_id;

  if p_total then
    insert into documento_lineas (
      documento_id, numero_linea, producto_id, presentacion_id, sku,
      descripcion, codigo_producto_sunat, unidad_medida, cantidad,
      factor_conversion, precio_unitario, dto1_pct, dto2_pct, dto3_pct,
      afectacion_igv, tasa_igv, coste_unitario_snapshot
    )
    select
      nc_id, numero_linea, producto_id, presentacion_id, sku,
      descripcion, codigo_producto_sunat, unidad_medida, cantidad,
      factor_conversion, precio_unitario, dto1_pct, dto2_pct, dto3_pct,
      afectacion_igv, tasa_igv, coste_unitario_snapshot
    from documento_lineas
    where documento_id = ref.id;

    perform app.recalcular_totales(nc_id);
  end if;

  return (select * from documentos where id = nc_id);
end;
$$;

-- Solo estas tres son llamables desde el cliente.
revoke all on function confirmar_documento(uuid) from public;
revoke all on function anular_documento(uuid, text) from public;
revoke all on function emitir_nota_credito(uuid, text, boolean) from public;
grant execute on function confirmar_documento(uuid) to authenticated;
grant execute on function anular_documento(uuid, text) to authenticated;
grant execute on function emitir_nota_credito(uuid, text, boolean) to authenticated;
