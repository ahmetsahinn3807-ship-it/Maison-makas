import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show
        AuthChangeEvent,
        AuthException,
        AuthResponse,
        AuthState,
        PostgrestException,
        Session,
        SupabaseClient,
        User;

/// Kullanıcıya gösterilecek, Türkçe hata.
class MaisonHata implements Exception {
  const MaisonHata(this.mesaj);

  final String mesaj;

  @override
  String toString() => mesaj;
}

/// Oturum ve profil durumu.
///
/// [istemci] yoksa (testlerde ya da sunucu başlatılamazsa) çevrimdışı çalışır:
/// giriş yapılmamış sayılır, listeler boş döner.
class MaisonOturum extends ChangeNotifier {
  MaisonOturum(this.istemci) {
    final SupabaseClient? i = istemci;
    if (i != null) {
      _abonelik = i.auth.onAuthStateChange.listen(_durumDegisti, onError: (Object _) {});
      if (i.auth.currentSession != null) {
        unawaited(profiliYukle());
      }
    }
  }

  final SupabaseClient? istemci;
  StreamSubscription<AuthState>? _abonelik;
  Map<String, dynamic>? _profil;

  Session? get oturum => istemci?.auth.currentSession;
  User? get kullanici => istemci?.auth.currentUser;
  bool get girisli => oturum != null;
  Map<String, dynamic>? get profil => _profil;
  String? get eposta => kullanici?.email;

  /// Profildeki ad; profil henüz gelmediyse kayıttaki ad.
  String get adSoyad {
    final Object? profilAdi = _profil?['ad_soyad'];
    if (profilAdi is String && profilAdi.trim().isNotEmpty) {
      return profilAdi.trim();
    }
    final Object? kayitAdi = kullanici?.userMetadata?['ad_soyad'];
    if (kayitAdi is String && kayitAdi.trim().isNotEmpty) {
      return kayitAdi.trim();
    }
    return '';
  }

  String get ilkAd {
    final String ad = adSoyad;
    if (ad.isEmpty) {
      return '';
    }
    return ad.split(RegExp(r'\s+')).first;
  }

  /// Avatar için baş harfler (en fazla iki).
  String get basHarfler {
    final List<String> parcalar =
        adSoyad.split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).toList();
    if (parcalar.isEmpty) {
      final String? e = eposta;
      return (e != null && e.isNotEmpty) ? e.substring(0, 1).toUpperCase() : 'M';
    }
    final String ilk = parcalar.first.substring(0, 1);
    final String son = parcalar.length > 1 ? parcalar.last.substring(0, 1) : '';
    return (ilk + son).toUpperCase();
  }

  void _durumDegisti(AuthState durum) {
    if (durum.event == AuthChangeEvent.signedOut) {
      _profil = null;
      notifyListeners();
      return;
    }
    notifyListeners();
    if (durum.session != null) {
      unawaited(profiliYukle());
    }
  }

  Future<void> profiliYukle() async {
    final SupabaseClient? i = istemci;
    final User? k = kullanici;
    if (i == null || k == null) {
      return;
    }
    try {
      final Map<String, dynamic>? satir =
          await i.from('profiller').select().eq('id', k.id).maybeSingle();
      _profil = satir;
      notifyListeners();
    } catch (_) {
      // Bağlantı yoksa profil bir sonraki açılışta yüklenir.
    }
  }

  Future<void> girisYap({required String eposta, required String sifre}) async {
    final SupabaseClient i = _istemciGerekli();
    await i.auth.signInWithPassword(email: eposta.trim(), password: sifre);
  }

  Future<void> kayitOl({
    required String adSoyad,
    required String eposta,
    required String sifre,
  }) async {
    final SupabaseClient i = _istemciGerekli();
    final AuthResponse yanit = await i.auth.signUp(
      email: eposta.trim(),
      password: sifre,
      data: <String, dynamic>{'ad_soyad': adSoyad.trim()},
    );
    if (yanit.session == null) {
      throw const MaisonHata(
        'Hesabın oluştu. E-postana gelen onay bağlantısına dokun, sonra giriş yap.',
      );
    }
  }

  Future<void> cikisYap() async {
    final SupabaseClient? i = istemci;
    if (i != null) {
      await i.auth.signOut();
    }
    _profil = null;
    notifyListeners();
  }

  /// Profilde verilen alanları günceller (ör. ad_soyad, telefon, gorunum, dil).
  Future<void> profilGuncelle(Map<String, dynamic> alanlar) async {
    final SupabaseClient i = _istemciGerekli();
    final User? k = kullanici;
    if (k == null) {
      throw const MaisonHata('Önce giriş yapmalısın.');
    }
    final Map<String, dynamic> satir =
        await i.from('profiller').update(alanlar).eq('id', k.id).select().single();
    _profil = satir;
    notifyListeners();
  }

  /// Hesabı ve kişisel verileri siler; ardından oturumu kapatır.
  ///
  /// [salonlarla] yalnız Makas Pro'da salon sahibi için `true` verilir:
  /// hesapla birlikte sahibi olduğu salonlar da silinir. Müşteri uygulaması
  /// `false` gönderir; salonu olan hesap orada silinmez.
  Future<void> hesabiSil({bool salonlarla = false}) async {
    final SupabaseClient i = _istemciGerekli();
    await i.rpc('hesabimi_sil', params: <String, dynamic>{'p_salonlarla': salonlarla});
    try {
      await i.auth.signOut();
    } catch (_) {
      // Hesap silindiği için sunucu oturumu zaten tanımaz.
    }
    _profil = null;
    notifyListeners();
  }

  SupabaseClient _istemciGerekli() {
    final SupabaseClient? i = istemci;
    if (i == null) {
      throw const MaisonHata('Sunucuya bağlanılamadı. İnternet bağlantını kontrol et.');
    }
    return i;
  }

  @override
  void dispose() {
    _abonelik?.cancel();
    super.dispose();
  }
}

/// [MaisonOturum] nesnesini alt ağaca taşır; oturum değişince bağımlılar yeniden çizilir.
class OturumKapsami extends InheritedNotifier<MaisonOturum> {
  const OturumKapsami({
    super.key,
    required MaisonOturum oturum,
    required super.child,
  }) : super(notifier: oturum);

  static MaisonOturum of(BuildContext context) {
    final OturumKapsami? kapsam = context.dependOnInheritedWidgetOfExactType<OturumKapsami>();
    assert(kapsam != null, 'OturumKapsami bulunamadı.');
    return kapsam!.notifier!;
  }

  /// Bağımlılık kurmadan okur (ör. bir düğmenin onTap içinde).
  static MaisonOturum oku(BuildContext context) {
    final OturumKapsami? kapsam =
        context.getInheritedWidgetOfExactType<OturumKapsami>();
    assert(kapsam != null, 'OturumKapsami bulunamadı.');
    return kapsam!.notifier!;
  }
}

/// Her hatayı kullanıcıya gösterilecek kısa bir Türkçe cümleye çevirir.
String maisonHataMetni(Object hata) {
  if (hata is MaisonHata) {
    return hata.mesaj;
  }
  if (hata is AuthException) {
    final String kod = (hata.code ?? '').toLowerCase();
    final String mesaj = hata.message.toLowerCase();
    if (kod == 'invalid_credentials' || mesaj.contains('invalid login')) {
      return 'E-posta ya da şifre hatalı.';
    }
    if (kod == 'user_already_exists' || mesaj.contains('already registered')) {
      return 'Bu e-postayla zaten bir hesap var. Giriş yap.';
    }
    if (kod == 'weak_password' || mesaj.contains('password should')) {
      return 'Şifre çok zayıf. En az 8 karakter kullan.';
    }
    if (kod == 'email_not_confirmed' || mesaj.contains('not confirmed')) {
      return 'E-postanı henüz onaylamadın. Gelen kutundaki bağlantıya dokun.';
    }
    if (kod == 'email_address_invalid' || mesaj.contains('invalid format')) {
      return 'Geçerli bir e-posta adresi yaz.';
    }
    if (kod.contains('rate_limit') || hata.statusCode == '429') {
      return 'Çok fazla deneme yapıldı. Biraz bekleyip tekrar dene.';
    }
    if (kod == 'signup_disabled') {
      return 'Yeni kayıtlar şu an kapalı.';
    }
    if (hata.statusCode == null) {
      return 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.';
    }
    return 'İşlem yapılamadı: ${hata.message}';
  }
  if (hata is PostgrestException) {
    final String kod = hata.code ?? '';
    final String mesaj = hata.message.toLowerCase();
    if (kod == 'PGRST202' || kod == '42883' || kod == 'PGRST205' || kod == '42P01') {
      return 'Sunucu kurulumu eksik: bu özelliğin SQL kodu henüz çalıştırılmamış.';
    }
    if (kod == '42501' && mesaj.contains('row-level security')) {
      return 'Bu işlem için yetkin yok.';
    }
    if (kod == '23505') {
      return 'Bu kayıt zaten var.';
    }
    if (kod == '23P01') {
      return 'Bu saat az önce doldu. Başka bir saat seç.';
    }
    if (kod == 'PGRST116') {
      return 'Kayıt bulunamadı.';
    }
    if (kod == 'PGRST301' || kod == 'PGRST303' || mesaj.contains('jwt expired')) {
      return 'Oturumun süresi doldu. Çıkış yapıp yeniden giriş yap.';
    }
    return hata.message;
  }
  final String metin = hata.toString();
  if (metin.contains('SocketException') ||
      metin.contains('ClientException') ||
      metin.contains('Failed host lookup') ||
      metin.contains('Connection')) {
    return 'İnternet bağlantını kontrol et.';
  }
  return 'Bir şeyler ters gitti. Tekrar dene.';
}
