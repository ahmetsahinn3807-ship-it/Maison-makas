import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, PostgresChangePayload, RealtimeChannel, SupabaseClient;

/// Makas Pro açıkken salonun randevularındaki değişiklikleri anında alır.
///
/// [onDegisti] her değişiklikte çağrılır (liste yenilensin diye); [onBildir] yalnız
/// salonun bilmesi gereken olaylarda: müşteri uygulamadan randevu aldı ya da iptal etti.
class SalonDinleyici {
  SalonDinleyici({
    required this.istemci,
    required this.salonId,
    required this.onDegisti,
    required this.onBildir,
  });

  final SupabaseClient istemci;
  final String salonId;
  final void Function() onDegisti;
  final void Function(String baslik, String metin) onBildir;

  RealtimeChannel? _kanal;

  void baslat() {
    try {
      _kanal = istemci
          .channel('salon-randevulari-$salonId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'randevular',
            filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'salon_id', value: salonId),
            callback: _geldi,
          )
          .subscribe();
    } catch (_) {
      _kanal = null; // Canlı bağlantı kurulamazsa liste elle yenilenir.
    }
  }

  /// `["2026-10-22 08:30:00+00","2026-10-22 09:00:00+00")` → başlangıç (telefonun saatiyle).
  static DateTime? araliginBasi(Object? aralik) {
    if (aralik is! String) {
      return null;
    }
    final RegExpMatch? m =
        RegExp(r'\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}(:\d{2}(\.\d+)?)?([+-]\d{2}(:?\d{2})?|Z)?').firstMatch(aralik);
    final String? metin = m?.group(0);
    return metin == null ? null : DateTime.tryParse(metin)?.toLocal();
  }

  static String _zaman(DateTime? t) {
    if (t == null) {
      return '';
    }
    final DateTime simdi = DateTime.now();
    final DateTime bugun = DateTime(simdi.year, simdi.month, simdi.day);
    final int fark = DateTime(t.year, t.month, t.day).difference(bugun).inDays;
    final String gun = fark == 0
        ? 'Bugün'
        : fark == 1
            ? 'Yarın'
            : '${maisonGun(t)} ${t.day} ${maisonAy(t)}';
    return '$gun · ${maisonSaat(t)}';
  }

  void _geldi(PostgresChangePayload olay) {
    final Map<String, dynamic> yeni = olay.newRecord;
    if (yeni['tur'] == 'randevu') {
      final String zaman = _zaman(araliginBasi(yeni['aralik']));
      final Object? musteri = yeni['musteri_id'];
      if (olay.eventType == PostgresChangeEvent.insert && yeni['kaynak'] == 'uygulama') {
        onBildir('Yeni randevu', zaman.isEmpty ? 'Maison Makas\'tan yeni bir randevu alındı.' : zaman);
      } else if (olay.eventType == PostgresChangeEvent.update &&
          yeni['durum'] == 'iptal' &&
          musteri != null &&
          yeni['iptal_eden'] == musteri) {
        onBildir('Randevu iptal edildi', zaman.isEmpty ? 'Müşteri randevusunu iptal etti.' : '$zaman · müşteri iptal etti');
      }
    }
    onDegisti();
  }

  Future<void> durdur() async {
    final RealtimeChannel? kanal = _kanal;
    _kanal = null;
    if (kanal != null) {
      try {
        await istemci.removeChannel(kanal);
      } catch (_) {
        // Kanal zaten kapanmış olabilir.
      }
    }
  }
}
