import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makas_core/makas_core.dart';
import 'package:pro/canli_takip.dart';
import 'package:pro/kisa_ad.dart';
import 'package:pro/main.dart';

void main() {
  testWidgets('Pro tanıtımı açılır, giriş ekranına geçilir', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MakasProUygulamasi(oturum: MaisonOturum(null)));
    await tester.pump();

    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('İşletme paneli'), findsOneWidget);
    expect(find.text('Bugün'), findsOneWidget);

    await tester.tap(find.text('Giriş yap'));
    await tester.pumpAndSettle();
    expect(find.text('Hoş geldin'), findsOneWidget);
    expect(find.text('MAKAS PRO'), findsOneWidget);
  });

  testWidgets('Makas Pro İngilizce açılır', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    MaisonTercih.dil.value = MaisonDil.en;
    addTearDown(() => MaisonTercih.dil.value = MaisonDil.tr);

    await tester.pumpWidget(MakasProUygulamasi(oturum: MaisonOturum(null)));
    await tester.pump();

    expect(find.text('Business dashboard'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  test('Salon kısa adı Türkçe harfleri ve işaretleri temizler', () {
    expect(kisaAdUret('Maison Şahin & Oğulları'), 'maison-sahin-ogullari');
    expect(kisaAdUret('İLKER BERBER'), 'ilker-berber');
    expect(kisaAdUret('Kuaför Işıl'), 'kuafor-isil');
    expect(kisaAdUret('  '), 'salon');
    expect(kisaAdUret('A'), 'salon-a');
    expect(kisaAdEki('maison-ahmet', 123), 'maison-ahmet-123');
  });

  test('Canlı bildirimdeki randevu aralığının başlangıcı okunur', () {
    expect(
      SalonDinleyici.araliginBasi('["2026-10-22 08:30:00+00","2026-10-22 09:00:00+00")'),
      DateTime.utc(2026, 10, 22, 8, 30).toLocal(),
    );
    expect(
      SalonDinleyici.araliginBasi('["2026-10-22 08:30:00.5+03:00","2026-10-22 09:00:00+03:00")'),
      DateTime.utc(2026, 10, 22, 5, 30, 0, 500).toLocal(),
    );
    expect(SalonDinleyici.araliginBasi(null), isNull);
    expect(SalonDinleyici.araliginBasi('bozuk'), isNull);
  });
}
