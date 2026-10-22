import 'dart:async';

import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, PostgresChangePayload, RealtimeChannel, SupabaseClient;

import 'veri.dart';

/// Müşterinin randevu hatırlatmaları: her yaklaşan randevu için 24 saat ve 2 saat önce.
///
/// Bildirimleri telefon kendisi zamanlar; uygulama kapalıyken de gelir. Randevu alınınca,
/// iptal edilince ya da uygulama açılınca liste baştan kurulur.
class RandevuHatirlatici {
  RandevuHatirlatici._();

  static bool _calisiyor = false;
  static bool _yeniden = false;

  /// Zamanlanmış hatırlatmaları güncel randevu listesine göre baştan kurar.
  static Future<void> esitle(Veri veri) async {
    if (veri.oturum.istemci == null || !veri.oturum.girisli) {
      return;
    }
    if (_calisiyor) {
      _yeniden = true;
      return;
    }
    _calisiyor = true;
    try {
      do {
        _yeniden = false;
        await _kur(veri);
      } while (_yeniden);
    } finally {
      _calisiyor = false;
    }
  }

  static Future<void> _kur(Veri veri) async {
    List<RandevuOzet> randevular;
    try {
      randevular = await veri.randevularim();
    } catch (_) {
      return; // Bağlantı yoksa eski hatırlatmalar kalır.
    }
    await MaisonBildirim.zamanlananlariKaldir();
    if (!await MaisonBildirim.hatirlatmaAcik()) {
      return;
    }
    int no = 0;
    for (final RandevuOzet r in randevular.take(20)) {
      final String saat = maisonSaat(r.baslangic);
      final String yer = r.ustaAd.isEmpty ? r.salonAd : dl('${r.salonAd} · Usta ${r.ustaAd}', '${r.salonAd} · ${r.ustaAd}');
      await MaisonBildirim.zamanla(
        id: 1000 + no * 2,
        zaman: r.baslangic.subtract(const Duration(hours: 24)),
        baslik: dl('Yarın randevun var', 'You have an appointment tomorrow'),
        metin: '$saat · $yer',
      );
      await MaisonBildirim.zamanla(
        id: 1001 + no * 2,
        zaman: r.baslangic.subtract(const Duration(hours: 2)),
        baslik: dl('Randevuna 2 saat kaldı', 'Your appointment is in 2 hours'),
        metin: '$saat · $yer',
      );
      no++;
    }
  }
}

/// Uygulama açıkken salonun randevuda yaptığı değişiklikleri dinler (ör. salon iptal etti).
class RandevuDinleyici {
  RandevuDinleyici(this._istemci, this._kullaniciId);

  final SupabaseClient _istemci;
  final String _kullaniciId;
  RealtimeChannel? _kanal;

  void baslat() {
    try {
      _kanal = _istemci
          .channel('musteri-randevulari-$_kullaniciId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'randevular',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'musteri_id',
              value: _kullaniciId,
            ),
            callback: _degisti,
          )
          .subscribe();
    } catch (_) {
      _kanal = null; // Canlı bağlantı kurulamazsa liste açılışta yenilenir.
    }
  }

  void _degisti(PostgresChangePayload olay) {
    final Map<String, dynamic> yeni = olay.newRecord;
    if (yeni['durum'] == 'iptal' && yeni['iptal_eden'] != _kullaniciId) {
      unawaited(
        MaisonBildirim.goster(
          id: 2000,
          baslik: dl('Randevun iptal edildi', 'Your appointment was cancelled'),
          metin: dl('Salon randevunu iptal etti. Ayrıntı için Randevularım\'a bak.', 'The salon cancelled your appointment. See My bookings for details.'),
        ),
      );
    }
    Veri.randevuSurumu.value++;
  }

  Future<void> durdur() async {
    final RealtimeChannel? kanal = _kanal;
    _kanal = null;
    if (kanal != null) {
      try {
        await _istemci.removeChannel(kanal);
      } catch (_) {
        // Kanal zaten kapanmış olabilir.
      }
    }
  }
}
