// lib/state/doc_identidad.dart
//
// Abreviaturas del catálogo 06 (`cat_tipo_doc_identidad`, ver
// `001_fundamentos.sql`) para rotular un número de documento. No es
// una validación: esa la hace el trigger `clientes_valida_doc`.

/// Código del catálogo 06 para RUC: el único que permite factura.
const codigoRuc = '6';

/// 'DNI', 'RUC', etc. para la etiqueta del documento de identidad.
String abreviaturaDocIdentidad(String codigo) {
  return switch (codigo) {
    '1' => 'DNI',
    codigoRuc => 'RUC',
    '4' => 'Carnet ext.',
    '7' => 'Pasaporte',
    _ => 'Doc.',
  };
}
