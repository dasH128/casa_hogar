// lib/ui/widgets/amount_text.dart

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Importe monetario en `AppTheme.mono()`. Formatea a dos decimales
/// para mostrar aunque el [Decimal] guarde más precisión, y nunca pasa
/// por `double`: los separadores de miles se insertan sobre el string
/// exacto que devuelve `Decimal.toStringAsFixed`.
class AmountText extends StatelessWidget {
  const AmountText(
    this.value, {
    super.key,
    this.currencySymbol,
    this.fontSize = 13,
    this.fontWeight = FontWeight.w400,
    this.color = AppColor.ink,
  });

  final Decimal value;
  final String? currencySymbol;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;

  static String format(Decimal value, {String locale = 'es_PE'}) {
    final fixed = value.abs().toStringAsFixed(2);
    final dot = fixed.indexOf('.');
    final intPart = fixed.substring(0, dot);
    final fractionPart = fixed.substring(dot + 1);

    final symbols = NumberFormat.decimalPattern(locale).symbols;
    final grouped = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      final remaining = intPart.length - i;
      if (i > 0 && remaining % 3 == 0) grouped.write(symbols.GROUP_SEP);
      grouped.write(intPart[i]);
    }

    final sign = value.sign < 0 ? '−' : '';
    return '$sign$grouped${symbols.DECIMAL_SEP}$fractionPart';
  }

  @override
  Widget build(BuildContext context) {
    final amount = format(value);
    return Text(
      currencySymbol == null ? amount : '$currencySymbol $amount',
      style: AppTheme.mono(size: fontSize, weight: fontWeight, color: color),
    );
  }
}
