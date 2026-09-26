# Especificación de interfaz

Este documento acompaña a los artboards de `design/artboards/`. Cada
artboard es un HTML autónomo: ábrelo en el navegador para ver la
pantalla, o léelo como texto para sacar medidas y colores exactos.

**Regla de oro:** ningún valor de color, espaciado o tipografía se
escribe en un widget. Todo sale de `lib/ui/core/theme/app_tokens.dart`.
Si falta un token, se añade allí, no en la pantalla.

---

## Estructura de carpetas esperada

MVVM por capas, según la arquitectura recomendada por Flutter: la UI se
agrupa por feature, datos y dominio por tipo.

```
lib/
  data/
    repositories/          un repositorio por área (cliente, venta, ...)
    repository_providers.dart   inyección de repositorios (Riverpod)
    supabase_errors.dart   traduce errores de Supabase a AppFailure
  domain/
    models/                modelos inmutables (Decimal, nunca double)
    failures.dart          AppFailure y sus subtipos
  state/                   estado global: perfil, sesión, catálogos
  routing/                 app_router.dart
  ui/
    core/
      theme/               app_tokens.dart, app_theme.dart
      shell/               AppShell (rail + header + contenido)
      widgets/             FieldLabel, AppField, StatusPill,
                           DataTableShell, SidePanelCard, KeyBar,
                           AmountText
    features/
      <feature>/
        view_models/       estado y acciones de la pantalla
        providers/         consultas y catálogos de solo lectura
        views/             pantallas; widgets/ para sus partes
```

`view_models/` y `providers/` se distinguen por lo que hace cada uno,
no por la clase de Riverpod:

| Carpeta        | Qué contiene | Forma típica | Ejemplo |
|----------------|--------------|--------------|---------|
| `view_models/` | Estado de una pantalla con acciones que lo cambian o escriben en la base de datos (cargar, editar, guardar, confirmar). Uno por pantalla. | Clase `Notifier` expuesta con `NotifierProvider` | `ClienteFichaViewModel`, `VentaFormViewModel` |
| `providers/`   | Datos que la pantalla solo observa: búsquedas, listados, opciones de desplegables. No escriben nada. | `FutureProvider`, y `StateProvider` para el término de búsqueda | `clientesListaProvider`, `zonasProvider` |

Si un provider empieza a necesitar acciones propias (paginar, marcar,
borrar), pasa a ser un ViewModel y se mueve a `view_models/`. Los
catálogos que comparten varias features van en `lib/state/`, no en
el `providers/` de una de ellas.

### Nombres

Cada pantalla y su ViewModel comparten un mismo prefijo, el de la
pantalla, no el de un detalle de implementación (por eso es
`VentaForm`, no `VentaDraft`: la pantalla también abre ventas ya
confirmadas).

| Pieza      | Archivo                                   | Nombre             |
|------------|-------------------------------------------|--------------------|
| Vista      | `views/<prefijo>_screen.dart`             | `<Prefijo>Screen`    |
| ViewModel  | `view_models/<prefijo>_view_model.dart`   | `<Prefijo>ViewModel` |
| Estado     | en el mismo archivo del ViewModel         | `<Prefijo>State`     |
| Provider   | en el mismo archivo del ViewModel         | `<prefijo>Provider`  |
| Partes     | `views/widgets/<prefijo>_<parte>_card.dart` | `<Prefijo><Parte>Card` |
| Consultas  | `providers/<tema>_providers.dart`         | `<tema>Provider`, `<tema>QueryProvider` |

Ejemplos actuales:

| Feature  | Vista                | ViewModel               | Estado              | Provider             |
|----------|----------------------|-------------------------|---------------------|----------------------|
| acceso   | `AccesoScreen`       | `AccesoViewModel`       | `AccesoState`       | `accesoProvider`     |
| clientes | `ClienteFichaScreen` | `ClienteFichaViewModel` | `ClienteFichaState` | `clienteFichaProvider` |
| ventas   | `VentaFormScreen`    | `VentaFormViewModel`    | `VentaFormState`    | `ventaFormProvider`  |

Un listado de solo lectura (como `ClientesScreen` o
`DocumentosScreen`) no necesita ViewModel: observa los providers de
`providers/` directamente. Si tiene varios filtros, van juntos en un
objeto inmutable (`DocumentosQuery`) dentro de un único
`<tema>QueryProvider`.

Features: `acceso`, `ventas`, `compras`, `documentos`, `catalogo`,
`clientes`, `usuarios`.

Reglas entre capas:
- Solo `data/` importa `supabase_flutter`. Los repositorios envuelven
  cada llamada con `ejecutarConSupabase`, y ViewModels y vistas
  capturan `AppFailure`, nunca `PostgrestException` ni `AuthException`.
- Los ViewModels leen los repositorios de `repository_providers.dart`
  (`ref.read`); no los construyen. Así un test los sustituye con
  `ProviderScope(overrides: [...])`.
- Las vistas no consultan datos: pintan el estado del ViewModel y le
  delegan las acciones.

## Dependencias

```yaml
dependencies:
  flutter_riverpod: ^3.4.3
  go_router: ^18.0.1
  google_fonts: ^8.2.1
  supabase_flutter: ^2.17.2
  decimal: ^3.2.6        # nunca double para dinero
  ntl: ^0.20.3           # formato de moneda y fecha
```

---

## Componentes compartidos

Estos salen de los artboards y se repiten en todas las pantallas.
Constrúyelos primero: el resto es composición.

### `AppShell`
Rail de 216 px (`AppColor.rail`) + columna de contenido.
- Rail: marca en `AppTheme.serif(size: 26)`, subtítulo en versalita
  `AppColor.railTextMuted`, items de 38 px de alto con radio 5. El
  activo lleva fondo `AppColor.railActive` y peso 600.
- Al pie del rail, nombre del usuario y "Rol · Sucursal".
- Header de 62 px sobre `AppColor.surface`, borde inferior
  `AppColor.line`, con título, chips y acciones a la derecha.
- Los items del rail se muestran u ocultan según el permiso del rol.
  Ocultarlos es cosmética: la autorización real la aplica RLS.

### `AppField`
`Column` de etiqueta + campo.
- Etiqueta: `Theme.of(context).textTheme.labelSmall`.
- Campo: 36 px de alto, radio 4, borde `AppColor.lineField`; enfocado
  pasa a `AppColor.primary`.
- Solo lectura: fondo `AppColor.readonly`, borde `AppColor.line`, texto
  `AppColor.inkMuted`.
- Los campos numéricos y de fecha usan `AppTheme.mono()`.
- Nota opcional debajo, 11 px `AppColor.inkFaint`.

### `StatusPill`
Texto de 10.5 px, peso 600, versalita, tracking 0.05em, radio 3,
padding 3/7. Mapa de estados:

| Estado            | Texto              | Fondo               |
|-------------------|--------------------|---------------------|
| BORRADOR          | `AppColor.inkMuted`| `AppColor.neutralSoft` |
| EMITIDO           | `AppColor.info`    | `AppColor.infoSoft` |
| PENDIENTE de envío| `AppColor.warn`    | `AppColor.warnSoft` |
| ACEPTADO          | `AppColor.primary` | `AppColor.primarySoft` |
| RECHAZADO         | `AppColor.danger`  | `AppColor.dangerSoft` |
| ANULADO           | `AppColor.neutral` | `AppColor.neutralSoft` |

### `DataTableShell`
No uses `DataTable` de Material: no permite el control de altura de fila
ni el pegado de cabecera que necesita una grilla densa. Usa
`Table` con `columnWidths` fijas, o `CustomScrollView` con
`SliverPersistentHeader` para la cabecera.
- Cabecera: fondo `AppColor.tableHeader`, texto 10 px versalita.
- Fila: 36 px (30 px en la grilla de compras), separador inferior
  `AppColor.lineSoft`.
- Fila con el cursor: fondo `AppColor.rowActive`.
- Columnas numéricas alineadas a la derecha con `AppTheme.mono()`.

### `AmountText`
Recibe un `Decimal` y una moneda. Formatea con `intl` a dos decimales
para mostrar, aunque el valor guarde cuatro. Nunca convierte a `double`.

### `KeyBar`
Barra de 46 px al pie del formulario de documento. Cada tecla es un
`kbd`: fondo `AppColor.tableHeader`, borde `AppColor.lineField` con
`borderBottom` de 2 px, radio 3, `AppTheme.mono(size: 10.5)`.

---

## Pantallas

### 1. Acceso — `design/artboards/Acceso.dc.html`
Ruta `/acceso`. Sin shell.
- Panel izquierdo fijo de 560 px, `AppColor.rail`, con la marca a 40 px
  y un titular en `AppTheme.serif(size: 34)` con `height: 1.32`.
- Formulario a la derecha, ancho 388 px, centrado. Campos de 44 px (no
  36: aquí no hay densidad que optimizar).
- Selector de sucursal y almacén antes de entrar. Lo elegido va al
  estado de sesión y precarga la cabecera de los documentos.
- Tras `signInWithPassword`, `go_router` redirige según el rol del
  perfil: vendedor a `/ventas/nueva`, almacén a `/compras`, el resto a
  `/documentos`.

### 2. Nueva venta — `design/artboards/Main.dc.html`
Ruta `/ventas/nueva` y `/ventas/:id`. **Es la pantalla crítica.**

Composición: cabecera en grid de 12 columnas, y debajo una fila con la
grilla de líneas (`Expanded`) y un panel lateral de 296 px.

Reparto de la cabecera: Documento 3, Serie·Número 2, Cliente 5,
Nº documento 2 / Almacén 3, Condición 3, Vendedor 2, Emisión 2,
Vencimiento 2.

Comportamiento:
- El vencimiento se calcula desde la condición de pago y es de solo
  lectura. Condición contado lo deja vacío.
- Cambiar el cliente carga su condición habitual y su límite de crédito.
- La última fila de la grilla es siempre el buscador de producto. Al
  elegir uno, se convierte en línea y aparece una fila vacía debajo.
- Los totales se recalculan en el servidor con `app.recalcular_totales`,
  no en Dart. Dart solo pinta lo que devuelve. Esto evita que la
  pantalla y la base de datos discrepen en el redondeo del IGV.
- El panel de stock refleja la línea con el foco.
- El aviso de crédito reproduce el texto del error que lanza
  `confirmar_documento()`, con los mismos números.

**Teclado.** Es lo que decide si el sistema se usa o se abandona.
Envuelve la pantalla en `Shortcuts` + `Actions`:

```dart
Shortcuts(
  shortcuts: const {
    SingleActivator(LogicalKeyboardKey.f2): GrabarIntent(),
    SingleActivator(LogicalKeyboardKey.f3): BuscarProductoIntent(),
    SingleActivator(LogicalKeyboardKey.f4): CopiarDocumentoIntent(),
    SingleActivator(LogicalKeyboardKey.f5): AnularIntent(),
    SingleActivator(LogicalKeyboardKey.f6): NotasIntent(),
    SingleActivator(LogicalKeyboardKey.f8): MonedaIntent(),
    SingleActivator(LogicalKeyboardKey.f9): ImpuestosIntent(),
    SingleActivator(LogicalKeyboardKey.delete, control: true):
        BorrarItemIntent(),
  },
  child: Actions(actions: {...}, child: FocusScope(child: ...)),
)
```

Dentro de la grilla, Enter avanza al campo siguiente y salta a la fila
nueva al llegar al final. Usa `FocusTraversalGroup` con
`OrderedTraversalPolicy` y `FocusTraversalOrder` por celda, en el orden
cantidad → precio → descuento → siguiente fila. Las flechas arriba y
abajo mueven de fila conservando la columna.

### 3. Documentos — `design/artboards/Documentos.dc.html`
Ruta `/documentos`.
- Cuatro tarjetas de resumen arriba en grid de 4 columnas iguales.
- Barra de filtros: búsqueda, tipo, estado, rango de fechas.
- Tabla con **dos columnas de estado separadas**: el estado del
  documento y el estado ante SUNAT. Una nota de salida está emitida y
  jamás tendrá CDR; una factura puede estar emitida y rechazada a la
  vez. Modelarlo como un solo campo es un error.
- Las filas pendiente y rechazada llevan fondo `AppColor.warnBg` y
  `AppColor.dangerBg`.
- Fila anulada: texto `AppColor.inkDisabled` y número tachado.

### 4. Compra de importación — `design/artboards/Compra.dc.html`
Ruta `/compras/nueva`.
- Misma estructura que la venta, con proveedor en lugar de cliente y
  moneda y tipo de cambio en cabecera.
- Filas compactas de 30 px: caben las nueve líneas de un invoice.
- Columna **Cajas** y columna **Unidades** juntas. La segunda es
  `cantidad × factor_conversion` y es la que va al stock.
- Precio unitario a cuatro decimales en la grilla. No lo redondees para
  mostrar: aquí el decimal es el argumento de venta.
- Panel lateral: total en moneda origen y su equivalente en soles al
  tipo de cambio del documento.

### 5. Ficha de producto — `design/artboards/Producto.dc.html`
Ruta `/catalogo/:id`.
- Atributos como campos editables (familia, modelo, tamaño, forma,
  perfil, línea).
- **Descripción de solo lectura**, generada por la base de datos. Es una
  columna `generated always as`. Si la haces editable, el catálogo se
  desincroniza en un mes.
- Tabla de presentaciones con columna "SKU antiguo" para la migración.
- El código de producto SUNAT valida ocho dígitos en el cliente, y el
  aviso de la fecha límite se muestra siempre mientras no sea exigible.

### 6. Ficha de cliente — `design/artboards/Cliente.dc.html`
Ruta `/clientes/:id`.
- El tipo de documento condiciona el resto: DNI implica boleta, y la
  interfaz lo dice en línea, sin esperar a un error al confirmar.
- Barra de crédito: usado sobre límite, con el disponible en negrita.
- Cuenta corriente al nivel de **cuota**, no de documento. Una factura a
  dos cuotas ocupa dos filas.

### 7. Usuarios y permisos — `design/artboards/Usuarios.dc.html`
Ruta `/usuarios`, visible solo con permiso `usuarios.read`.
- Lista de usuarios con rol, sucursal y último acceso.
- Matriz de permisos: filas recurso·acción, columnas rol. Cada casilla
  es una fila de la tabla `permisos`. Marcarla es un INSERT, no un
  despliegue.
- El punto verde de la matriz lleva texto alternativo oculto: no puede
  depender solo del color.

---

## Lo que no debe hacer la interfaz

- Calcular totales, IGV o descuentos. Eso es `app.recalcular_totales`.
- Asignar correlativos. Eso es `app.siguiente_correlativo`, con bloqueo.
- Insertar en `movimientos_stock`. Solo lo hacen las funciones
  `SECURITY DEFINER`.
- Decidir permisos. Ocultar un botón es cortesía; RLS es la seguridad.
- Usar `double` en cualquier punto de la cadena del dinero.
