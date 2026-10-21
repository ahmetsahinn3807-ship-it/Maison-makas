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
        StorageException,
        SupabaseClient,
        User;

import 'baslatma.dart';
import 'fotograf_yukleme.dart';

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
/// giriş yapılmamış sayılır, listeler boş döner. Bir işlem sunucu gerektirdiğinde
/// [yenidenBaslat] verilmişse bağlantı bir kez daha denenir.
class MaisonOturum extends ChangeNotifier {
  MaisonOturum(
    SupabaseClient? istemci, {
    String? baslatmaHatasi,
    Future<MaisonBaslatma> Function()? yenidenBaslat,
  })  : _istemci = istemci,
        _baslatmaHatasi = baslatmaHatasi,
        _yenidenBaslat = yenidenBaslat {
    _baglan();
  }

  /// Uygulama açılışındaki başlatma sonucundan oturum kurar.
  factory MaisonOturum.baslatmadan(MaisonBaslatma baslatma) {
    return MaisonOturum(
      baslatma.istemci,
      baslatmaHatasi: baslatma.hata,
      yenidenBaslat: maisonSupabaseBaslat,
    );
  }

  SupabaseClient? _istemci;
  String? _baslatmaHatasi;
  final Future<MaisonBaslatma> Function()? _yenidenBaslat;
  StreamSubscription<AuthState>? _abonelik;
  Map<String, dynamic>? _profil;

  SupabaseClient? get istemci => _istemci;

  /// Bağlantı ya da cihaz deposuyla ilgili sorun; her şey yolundaysa null.
  /// Ayarlar ekranında küçük bir tanılama satırı olarak gösterilir.
  String? get tanilama {
    if (_istemci == null) {
      final String? neden = _baslatmaHatasi;
      return neden == null ? 'Sunucu bağlantısı yok' : 'Sunucu bağlantısı yok: ${_kisalt(neden)}';
    }
    final String? depo = MaisonYerelDepo.sorun;
    if (depo != null) {
      return 'Oturum bu cihazda saklanamıyor: ${_kisalt(depo)}';
    }
    final String? hata = _baslatmaHatasi;
    return hata == null ? null : 'Başlatma uyarısı: ${_kisalt(hata)}';
  }

  void _baglan() {
    final SupabaseClient? i = _istemci;
    if (i == null || _abonelik != null) {
      return;
    }
    _abonelik = i.auth.onAuthStateChange.listen(_durumDegisti, onError: (Object _) {});
    if (i.auth.currentSession != null) {
      unawaited(profiliYukle());
    }
  }

  Session? get oturum => _istemci?.auth.currentSession;
  User? get kullanici => _istemci?.auth.currentUser;
  bool get girisli => oturum != null;
  Map<String, dynamic>? get profil => _profil;
  String? get eposta => kullanici?.email;

  /// Profil fotoğrafının adresi (yüklendiyse).
  String? get avatarUrl => _metin(_profil?['avatar_url']);

  /// Kapak fotoğrafının adresi (yüklendiyse).
  String? get kapakUrl => _metin(_profil?['kapak_url']);

  /// Kapak fotoğrafının odak noktası (0–1).
  Offset get kapakOdak => Offset(_oran(_profil?['kapak_odak_x']), _oran(_profil?['kapak_odak_y']));

  static String? _metin(Object? deger) => deger is String && deger.isNotEmpty ? deger : null;

  static double _oran(Object? deger) =>
      deger is num ? deger.toDouble().clamp(0.0, 1.0).toDouble() : 0.5;

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
    final SupabaseClient? i = _istemci;
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
    final SupabaseClient i = await istemciGerekli();
    await i.auth.signInWithPassword(email: eposta.trim(), password: sifre);
  }

  Future<void> kayitOl({
    required String adSoyad,
    required String eposta,
    required String sifre,
  }) async {
    final SupabaseClient i = await istemciGerekli();
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
    final SupabaseClient? i = _istemci;
    if (i != null) {
      await i.auth.signOut();
    }
    _profil = null;
    notifyListeners();
  }

  /// Profilde verilen alanları günceller (ör. ad_soyad, telefon, gorunum, dil).
  Future<void> profilGuncelle(Map<String, dynamic> alanlar) async {
    final SupabaseClient i = await istemciGerekli();
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
    final SupabaseClient i = await istemciGerekli();
    final User? k = kullanici;
    if (k != null) {
      // Fotoğraflar yalnız Storage API ile silinir; hesap ve salon silinmeden önce temizlenir.
      if (salonlarla) {
        final List<Map<String, dynamic>> salonlar =
            await i.from('salonlar').select('id').eq('sahip_id', k.id);
        final List<String> kimlikler =
            salonlar.map((Map<String, dynamic> m) => m['id']).whereType<String>().toList();
        if (kimlikler.isNotEmpty) {
          final String simdi = DateTime.now().toUtc().toIso8601String();
          final List<Map<String, dynamic>> yaklasan = await i
              .from('randevular')
              .select('id')
              .inFilter('salon_id', kimlikler)
              .eq('tur', 'randevu')
              .inFilter('durum', <String>['bekliyor', 'onaylandi'])
              .overlaps('aralik', '[$simdi,infinity)');
          if (yaklasan.isNotEmpty) {
            throw MaisonHata(
              'Salonunda ${yaklasan.length} yaklaşan randevu var. Önce bunları iptal et, sonra hesabını sil.',
            );
          }
          for (final String salonId in kimlikler) {
            await maisonKlasoruBosalt(i, 'salon', salonId);
          }
        }
      }
      await maisonKlasoruBosalt(i, 'profil', k.id);
    }
    await i.rpc('hesabimi_sil', params: <String, dynamic>{'p_salonlarla': salonlarla});
    try {
      await i.auth.signOut();
    } catch (_) {
      // Hesap silindiği için sunucu oturumu zaten tanımaz.
    }
    _profil = null;
    notifyListeners();
  }

  /// Sunucu istemcisini verir. Açılışta bağlantı kurulamadıysa bir kez daha dener;
  /// yine olmazsa hatanın ayrıntısıyla birlikte [MaisonHata] fırlatır.
  Future<SupabaseClient> istemciGerekli() async {
    final SupabaseClient? hazir = _istemci;
    if (hazir != null) {
      return hazir;
    }
    final Future<MaisonBaslatma> Function()? yeniden = _yenidenBaslat;
    if (yeniden != null) {
      final MaisonBaslatma sonuc = await yeniden();
      final SupabaseClient? yeni = sonuc.istemci;
      _baslatmaHatasi = sonuc.hata ?? _baslatmaHatasi;
      if (yeni != null) {
        _istemci = yeni;
        _baglan();
        notifyListeners();
        return yeni;
      }
    }
    final String? ayrinti = _baslatmaHatasi;
    throw MaisonHata(
      ayrinti == null
          ? 'Sunucu bağlantısı kurulamadı. İnterneti kontrol edip tekrar dene.'
          : 'Sunucu bağlantısı kurulamadı. Ayrıntı: ${_kisalt(ayrinti)}',
    );
  }

  static String _kisalt(String metin) {
    final String tek = metin.replaceAll(RegExp(r'\s+'), ' ').trim();
    return tek.length <= 220 ? tek : '${tek.substring(0, 220)}…';
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
  if (hata is StorageException) {
    final String mesaj = '${hata.message} ${hata.error ?? ''}'.toLowerCase();
    if (mesaj.contains('bucket not found')) {
      return 'Fotoğraf deposu kurulu değil: 19. adımın SQL kodunu çalıştır.';
    }
    if (mesaj.contains('row-level security') || hata.statusCode == '403') {
      return 'Bu fotoğrafı yüklemeye ya da silmeye yetkin yok.';
    }
    if (mesaj.contains('maximum allowed size') || mesaj.contains('too large') || hata.statusCode == '413') {
      return 'Fotoğraf çok büyük; en çok 6 MB olabilir.';
    }
    if (mesaj.contains('mime type') || mesaj.contains('invalid_mime_type')) {
      return 'Bu fotoğraf biçimi desteklenmiyor. JPG ya da PNG bir fotoğraf seç.';
    }
    return 'Fotoğraf yüklenemedi: ${hata.message}';
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
    if (kod == '23503') {
      return 'Bu kayıt başka kayıtlarda kullanıldığı için silinemez.';
    }
    if (kod == '23514') {
      return 'Girdiğin bilgilerden biri kurala uymuyor (ör. çok uzun ya da geçersiz).';
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
