import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Ayarlarda yazan sürüm pubspec.yaml ile aynı', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final String surum = RegExp(r'^version:\s*([0-9.]+)', multiLine: true).firstMatch(pubspec)!.group(1)!;
    final String ayarlar = File('lib/ekranlar/pro_ayarlar.dart').readAsStringSync();
    expect(ayarlar, contains('sürüm $surum'));
    expect(ayarlar, contains('version $surum'));
  });
}
