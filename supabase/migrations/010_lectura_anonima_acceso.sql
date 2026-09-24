-- ============================================================
-- 010_lectura_anonima_acceso.sql
-- El selector de sucursal y almacén de /acceso (ver docs/ui-spec.md,
-- pantalla "1. Acceso") se elige ANTES de iniciar sesión, con el rol
-- `anon`. Las políticas de 006/008 solo dan lectura a `authenticated`,
-- así que el desplegable salía vacío sin ningún error.
--
-- Solo nombres de sucursal/almacén, nada sensible: se puede leer sin
-- autenticar.
-- ============================================================

create policy sucursales_lectura_anonima on sucursales
  for select to anon using (activo);

create policy almacenes_lectura_anonima on almacenes
  for select to anon using (activo);
