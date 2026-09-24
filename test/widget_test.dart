import 'package:flutter_test/flutter_test.dart';

import 'package:casa_hogar/main.dart';

void main() {
  testWidgets('Sin Supabase configurado, muestra el aviso de configuración', (tester) async {
    await tester.pumpWidget(const MorellaApp());

    expect(find.textContaining('Falta configurar Supabase'), findsOneWidget);
  });
}
