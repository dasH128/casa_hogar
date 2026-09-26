// lib/domain/estado_documento.dart
//
// Valores del enum `estado_documento` (ver `001_fundamentos.sql`) y
// su texto para la interfaz. Lo comparten `StatusPill` y el filtro de
// estado de Documentos, para que ambos digan lo mismo.

const estadosDocumento = [
  'BORRADOR',
  'EMITIDO',
  'ENVIANDO',
  'ACEPTADO',
  'OBSERVADO',
  'RECHAZADO',
  'ANULADO',
];

/// `ENVIANDO` se muestra como "Pendiente": es el estado en cola hacia
/// el PSE/OSE (ver la tabla de `StatusPill` en `docs/ui-spec.md`).
String etiquetaEstadoDocumento(String estado) {
  return switch (estado) {
    'BORRADOR' => 'Borrador',
    'EMITIDO' => 'Emitido',
    'ENVIANDO' => 'Pendiente',
    'ACEPTADO' => 'Aceptado',
    'OBSERVADO' => 'Observado',
    'RECHAZADO' => 'Rechazado',
    'ANULADO' => 'Anulado',
    _ => estado,
  };
}
