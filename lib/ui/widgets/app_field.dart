// lib/ui/widgets/app_field.dart

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';
import 'field_label.dart';

/// Columna de etiqueta + campo, reutilizada en toda cabecera de
/// documento. Por defecto es la variante densa de 36 px / radio 4 del
/// spec de `AppField`; con [dense]=false pasa a los 44 px / radio 6
/// "sin densidad que optimizar" del formulario de acceso. El borde y
/// el color de fondo cambian en modo solo lectura.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.readOnly = false,
    this.monospace = false,
    this.dense = true,
    this.obscureText = false,
    this.note,
    this.onChanged,
    this.focusNode,
    this.keyboardType,
    this.textAlign = TextAlign.start,
    this.child,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final bool readOnly;
  final bool monospace;
  final bool dense;
  final bool obscureText;
  final String? note;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextAlign textAlign;

  /// Sustituye el campo de texto por defecto, p. ej. un desplegable.
  /// [AppField] sigue aportando la etiqueta y el alto del campo; usa
  /// [decoration] y [textStyleFor] para que el desplegable comparta el
  /// mismo borde, color y tipografía que un campo de texto normal.
  final Widget? child;

  static double heightFor({required bool dense}) =>
      dense ? AppSize.fieldHeight : AppSize.authFieldHeight;

  /// Decoración compartida por el campo de texto por defecto y por
  /// cualquier [child] que quiera verse como un `AppField` (p. ej. un
  /// `DropdownButtonFormField`).
  static InputDecoration decoration({bool dense = true, bool readOnly = false}) {
    final radius = dense ? AppRadius.field : AppRadius.authControl;

    if (dense) {
      return InputDecoration(
        isDense: true,
        isCollapsed: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        fillColor: readOnly ? AppColor.readonly : null,
        enabledBorder: readOnly ? _border(AppColor.line, radius) : null,
        disabledBorder: readOnly ? _border(AppColor.line, radius) : null,
        focusedBorder: readOnly ? _border(AppColor.line, radius) : null,
      );
    }

    final borderColor = readOnly ? AppColor.line : AppColor.lineField;
    return InputDecoration(
      isDense: true,
      isCollapsed: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13),
      filled: true,
      fillColor: readOnly ? AppColor.readonly : AppColor.surface,
      border: _border(borderColor, radius),
      enabledBorder: _border(borderColor, radius),
      focusedBorder: _border(readOnly ? AppColor.line : AppColor.primary, radius),
      disabledBorder: _border(AppColor.line, radius),
    );
  }

  static TextStyle? textStyleFor(
    BuildContext context, {
    bool dense = true,
    bool monospace = false,
    bool readOnly = false,
  }) {
    final color = readOnly ? AppColor.inkMuted : AppColor.ink;
    if (monospace) return AppTheme.mono(size: dense ? 13 : 14, color: color);
    final base = Theme.of(context).textTheme.bodyMedium;
    return dense ? base?.copyWith(color: color) : base?.copyWith(fontSize: 14, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final field = child ??
        TextFormField(
          controller: controller,
          initialValue: controller == null ? initialValue : null,
          readOnly: readOnly,
          obscureText: obscureText,
          focusNode: focusNode,
          onChanged: onChanged,
          keyboardType: keyboardType,
          textAlign: textAlign,
          style: textStyleFor(context, dense: dense, monospace: monospace, readOnly: readOnly),
          decoration: decoration(dense: dense, readOnly: readOnly),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FieldLabel(label),
        SizedBox(height: dense ? AppSpace.xs : 6),
        SizedBox(height: heightFor(dense: dense), child: field),
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(note!, style: const TextStyle(fontSize: 11, color: AppColor.inkFaint)),
        ],
      ],
    );
  }

  static OutlineInputBorder _border(Color color, double radius) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: color),
      );
}
