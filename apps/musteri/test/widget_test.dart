import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:makas_core/makas_core.dart';
import 'package:musteri/ekranlar/kabuk.dart';
import 'package:musteri/gorunum.dart';
import 'package:musteri/main.dart';

void _telefonBoyutu(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('Açılış markayı gösterir, dil değişir, kayıt ekranı açılır',
      (WidgetTester tester) async {
    _telefonBoyutu(tester);

    await tester.pumpWidget(MaisonMakasUygulamasi(oturum: MaisonOturum(null)));
    await tester.pump(const Duration(milliseconds: 2500));

    expect(find.text('Makas'), findsOneWidget);
    expect(find.text('Usta ellere, tek dokunuşla.'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pump();
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('I have an account, sign in'), findsOneWidget);

    await tester.tap(find.text('TR'));
    await tester.pump();

    await tester.tap(find.text('Hemen başla'));
    await tester.pumpAndSettle();
    expect(find.text('Hesap oluştur'), findsOneWidget);
    expect(find.text('Hesabımı oluştur'), findsOneWidget);

    await tester.tap(find.text('Giriş'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hoş geldin'), findsOneWidget);

    // Boş form gönderilince uyarı çıkar, sunucuya gidilmez.
    await tester.tap(find.text('Giriş yap'));
    await tester.pump();
    expect(find.text('Geçerli bir e-posta adresi yaz.'), findsOneWidget);
  });

  testWidgets('Ana kabuk: menü açılır, sekmeler ve görünüm çalışır', (WidgetTester tester) async {
    _telefonBoyutu(tester);
    final MaisonOturum oturum = MaisonOturum(null);
    final Gorunum gorunum = Gorunum();
    addTearDown(gorunum.dispose);

    await tester.pumpWidget(
      OturumKapsami(
        oturum: oturum,
        child: GorunumKapsami(
          gorunum: gorunum,
          child: ListenableBuilder(
            listenable: gorunum,
            builder: (BuildContext context, Widget? child) {
              return MaterialApp(
                theme: maisonTemasi(gorunum.palet, vurgu: gorunum.vurgu),
                home: const Kabuk(),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Merhaba'), findsOneWidget);
    expect(find.text('Yaklaşan randevun yok'), findsWidgets);

    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();
    expect(find.text('Cüzdan ve sadakat'), findsOneWidget);
    expect(find.text('Koyu mod'), findsOneWidget);

    await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.text('Geçmiş')));
    await tester.pumpAndSettle();
    expect(find.text('Geçmiş randevun yok'), findsWidgets);

    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(Drawer), matching: find.text('Görünüm')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ivoire'));
    await tester.pumpAndSettle();
    expect(gorunum.palet.kimlik, 'ivoire');
    expect(find.text('Bronz'), findsOneWidget);
  });
}
