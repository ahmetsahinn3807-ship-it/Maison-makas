import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musteri/main.dart';

void main() {
  testWidgets('Açılış markayı gösterir, dil değişir, önizlemeye geçilir',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaisonMakasUygulamasi());
    await tester.pump(const Duration(milliseconds: 2500));

    expect(find.text('Makas'), findsOneWidget);
    expect(find.text('Usta ellere, tek dokunuşla.'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pump();
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.text('TR'));
    await tester.pump();
    expect(find.text('Hemen başla'), findsOneWidget);

    await tester.tap(find.text('Hemen başla'));
    await tester.pumpAndSettle();
    expect(find.text('Hoş geldin.'), findsOneWidget);

    await tester.tap(find.text('Ivoire'));
    await tester.pumpAndSettle();
    expect(find.text('Bronz'), findsOneWidget);
  });
}
