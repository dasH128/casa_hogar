// lib/ui/core/widgets/field_label.dart

import 'package:flutter/material.dart';

/// Etiqueta de 10 px en versalita usada sobre [AppField] y en cabeceras
/// de panel lateral. El estilo sale de `Theme.textTheme.labelSmall`.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall,
    );
  }
}
