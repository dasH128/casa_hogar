// lib/ui/core/widgets/key_bar.dart

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Un atajo mostrado en [KeyBar]: la tecla y lo que hace.
class KeyBarItem {
  const KeyBarItem({required this.keyLabel, required this.description});

  final String keyLabel;
  final String description;
}

/// Barra de 46 px al pie del formulario de documento, con los atajos
/// de teclado activos en la pantalla.
class KeyBar extends StatelessWidget {
  const KeyBar({super.key, required this.items});

  final List<KeyBarItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSize.keyBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
      decoration: const BoxDecoration(
        color: AppColor.surface,
        border: Border(top: BorderSide(color: AppColor.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpace.lg),
            _KeyBarEntry(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _KeyBarEntry extends StatelessWidget {
  const _KeyBarEntry({required this.item});

  final KeyBarItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColor.tableHeader,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: const Border(
              top: BorderSide(color: AppColor.lineField),
              left: BorderSide(color: AppColor.lineField),
              right: BorderSide(color: AppColor.lineField),
              bottom: BorderSide(color: AppColor.lineField, width: 2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            child: Text(
              item.keyLabel,
              style: AppTheme.mono(size: 10.5, color: AppColor.ink),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          item.description,
          style: const TextStyle(fontSize: 11.5, color: AppColor.inkMuted),
        ),
      ],
    );
  }
}
