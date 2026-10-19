import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pro/main.dart';

void main() {
  testWidgets('Pro karşılama ekranı açılır', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MakasProUygulamasi());
    await tester.pump();

    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('İşletme paneli'), findsOneWidget);
    expect(find.text('Bugün'), findsOneWidget);
  });
}
