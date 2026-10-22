import 'package:flutter/material.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../isletme.dart';
import '../salon.dart';

/// Takvimde gereken tanımlar: yazılabilecek ustalar ve aktif hizmetler.
@immutable
class TakvimTanimlari {
  const TakvimTanimlari({required this.ustalar, required this.hizmetler});

  /// Salon sahibine bütün aktif ustalar, ustaya yalnız kendisi.
  final List<ProUsta> ustalar;
  final List<ProHizmet> hizmetler;

  static Future<TakvimTanimlari> yukle(SupabaseClient i, ProSalon salon, String? benimId) async {
    final List<Object?> sonuc = await Future.wait<Object?>(<Future<Object?>>[
      i
          .from('ustalar')
          .select(ProUsta.sutunlar)
          .eq('salon_id', salon.id)
          .eq('aktif', true)
          .order('sira', ascending: true)
          .order('olusturuldu', ascending: true),
      i
          .from('hizmetler')
          .select(ProHizmet.sutunlar)
          .eq('salon_id', salon.id)
          .eq('aktif', true)
          .order('sira', ascending: true)
          .order('ad', ascending: true),
    ]);
    List<Map<String, dynamic>> satirlar(Object? liste) =>
        liste is List ? liste.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];
    List<ProUsta> ustalar = satirlar(sonuc[0]).map(ProUsta.json).toList();
    if (!salon.sahibim) {
      ustalar = ustalar.where((ProUsta u) => u.kullaniciId != null && u.kullaniciId == benimId).toList();
    }
    return TakvimTanimlari(ustalar: ustalar, hizmetler: satirlar(sonuc[1]).map(ProHizmet.json).toList());
  }
}

/// Gece yarısından dakika → o günün saati.
DateTime gununSaati(DateTime gun, int dakika) => DateTime(gun.year, gun.month, gun.day).add(Duration(minutes: dakika));

/// Randevu ya da molanın ayrıntısı ve işlemleri. Bir şey değiştiyse true döner.
Future<bool> randevuAyrintisiAc(BuildContext context, TakvimKaydi kayit) async {
  final MaisonRenkler r = MaisonRenkler.of(context);
  final bool? degisti = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: r.kart,
    showDragHandle: true,
    builder: (BuildContext context) => _RandevuAyrintisi(kayit: kayit),
  );
  return degisti ?? false;
}

class _RandevuAyrintisi extends StatefulWidget {
  const _RandevuAyrintisi({required this.kayit});

  final TakvimKaydi kayit;

  @override
  State<_RandevuAyrintisi> createState() => _RandevuAyrintisiState();
}

class _RandevuAyrintisiState extends State<_RandevuAyrintisi> {
  bool _isleniyor = false;
  String? _hata;

  Future<void> _calistir(Future<void> Function(SupabaseClient i) gorev) async {
    if (_isleniyor) {
      return;
    }
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final NavigatorState gezgin = Navigator.of(context);
    setState(() {
      _isleniyor = true;
      _hata = null;
    });
    try {
      await gorev(await oturum.istemciGerekli());
      gezgin.pop(true);
    } catch (hata) {
      if (mounted) {
        setState(() {
          _isleniyor = false;
          _hata = maisonHataMetni(hata);
        });
      }
    }
  }

  Future<void> _durum(String durum) => _calistir((SupabaseClient i) async {
        await i.rpc('randevu_durumu', params: <String, dynamic>{'p_randevu': widget.kayit.id, 'p_durum': durum});
      });

  Future<void> _iptal() async {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final bool? eminim = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: r.kart,
        title: Text(dl('Randevu iptal edilsin mi?', 'Cancel this booking?'), style: maisonBaslik(24, renk: r.yazi, kalinlik: FontWeight.w600)),
        content: Text(
          dl('Saat boşalır ve başka bir müşteri alabilir. Müşteri uygulamadan aldıysa randevusu iptal görünür.', 'The slot becomes free for another customer. If the customer booked in the app, they will see it as cancelled.'),
          style: maisonGovde(14, renk: r.soluk, yukseklik: 1.5),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(dl('Vazgeç', 'Keep it'))),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(dl('İptal et', 'Cancel booking'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (eminim != true || !mounted) {
      return;
    }
    await _calistir((SupabaseClient i) async {
      await i.rpc('randevu_iptal', params: <String, dynamic>{'p_randevu': widget.kayit.id});
    });
  }

  Future<void> _blokSil() => _calistir((SupabaseClient i) async {
        await i.from('randevular').delete().eq('id', widget.kayit.id);
      });

  Future<void> _ara(String tel) async {
    final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
    if (!await maisonTelefonAc(tel)) {
      mesaj.showSnackBar(SnackBar(content: Text(dl('Arama açılamadı.', 'The call could not be started.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final TakvimKaydi k = widget.kayit;
    final Color hataRengi = Theme.of(context).colorScheme.error;
    final String? tel = k.musteriTel;
    final String? not = k.blok ? k.ustaNotu : k.not;
    final double? fiyat = k.toplamFiyat;
    final bool acik = k.durum == 'bekliyor' || k.durum == 'onaylandi';
    final String? hata = _hata;
    final List<(String, String)> satirlar = <(String, String)>[
      (dl('Saat', 'Time'), '${maisonGun(k.baslangic)}, ${k.baslangic.day} ${maisonAy(k.baslangic)} · '
          '${maisonSaat(k.baslangic)}–${maisonSaat(k.bitis)}'),
      (dl('Usta', 'Barber'), k.ustaAd),
      if (!k.blok) (dl('Hizmet', 'Service'), k.hizmetler ?? dl('Belirtilmedi', 'Not specified')),
      if (!k.blok && fiyat != null) (dl('Tutar', 'Amount'), maisonPara(fiyat, 'TRY')),
      if (!k.blok) (dl('Kaynak', 'Source'), k.kaynak == 'dukkan' ? dl('Dükkânda yazıldı', 'Added at the salon') : 'Maison Makas'),
      if (!k.blok) (dl('Durum', 'Status'), k.durumMetni),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              k.blok ? (k.ustaNotu?.trim().isNotEmpty ?? false ? k.ustaNotu!.trim() : dl('Mola', 'Break')) : (k.musteriAd ?? dl('Misafir', 'Guest')),
              style: maisonBaslik(30, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.1),
            ),
            if (tel != null && tel.trim().isNotEmpty && !k.blok) ...<Widget>[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _ara(tel),
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: Text(tel),
                ),
              ),
            ],
            const SizedBox(height: 8),
            for (final (String etiket, String deger) in satirlar)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: r.cizgi))),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(width: 72, child: Text(etiket, style: maisonGovde(13, renk: r.soluk, yukseklik: 1.4))),
                    Expanded(
                      child: Text(
                        deger,
                        textAlign: TextAlign.end,
                        style: maisonGovde(14, renk: r.yazi, kalinlik: FontWeight.w500, yukseklik: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            if (not != null && not.trim().isNotEmpty && !k.blok) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: r.zemin, borderRadius: BorderRadius.circular(14)),
                child: Text(dl('Not: ${not.trim()}', 'Note: ${not.trim()}'), style: maisonGovde(14, renk: r.yazi, yukseklik: 1.5)),
              ),
            ],
            if (hata != null) ...<Widget>[
              const SizedBox(height: 12),
              MaisonHataKutusu(hata),
            ],
            const SizedBox(height: 18),
            if (k.blok)
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isleniyor ? null : _blokSil,
                  icon: Icon(Icons.delete_outline, color: hataRengi, size: 18),
                  label: Text(dl('Molayı kaldır', 'Remove break'), style: TextStyle(color: hataRengi)),
                ),
              )
            else ...<Widget>[
              if (acik && k.basladi)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: _isleniyor ? null : () => _durum('tamamlandi'),
                          child: Text(dl('Geldi', 'Arrived')),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _isleniyor ? null : () => _durum('gelmedi'),
                          child: Text(dl('Gelmedi', 'No-show')),
                        ),
                      ),
                    ),
                  ],
                ),
              if (k.durum == 'bekliyor') ...<Widget>[
                const SizedBox(height: 10),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _isleniyor ? null : () => _durum('onaylandi'),
                    child: Text(dl('Onayla', 'Confirm')),
                  ),
                ),
              ],
              if (k.durum == 'tamamlandi' || k.durum == 'gelmedi')
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _isleniyor ? null : () => _durum('onaylandi'),
                    child: Text(dl('İşareti geri al', 'Undo mark')),
                  ),
                ),
              if (acik) ...<Widget>[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _isleniyor ? null : _iptal,
                  child: Text(
                    dl('Randevuyu iptal et', 'Cancel booking'),
                    style: maisonGovde(14, renk: hataRengi, kalinlik: FontWeight.w600),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Kapıdan gelen ya da telefonla arayan müşteri. Kaydedilirse true.
Future<bool> kapidanGelenAc(
  BuildContext context, {
  required ProSalon salon,
  required TakvimTanimlari tanimlar,
  DateTime? zaman,
  String? ustaId,
}) async {
  if (tanimlar.ustalar.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          salon.sahibim
              ? dl('Önce Ekip ekranından usta ekle (kendini de ekleyebilirsin).', 'Add a barber on the Team screen first (you can add yourself too).')
              : dl('Bu salonda aktif bir usta kaydın yok.', 'You do not have an active barber record at this salon.'),
        ),
      ),
    );
    return false;
  }
  final MaisonRenkler r = MaisonRenkler.of(context);
  final bool? kaydedildi = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: r.kart,
    showDragHandle: true,
    builder: (BuildContext context) => _KapidanGelenFormu(
      salon: salon,
      tanimlar: tanimlar,
      zaman: zaman,
      ustaId: ustaId,
    ),
  );
  return kaydedildi ?? false;
}

class _KapidanGelenFormu extends StatefulWidget {
  const _KapidanGelenFormu({required this.salon, required this.tanimlar, this.zaman, this.ustaId});

  final ProSalon salon;
  final TakvimTanimlari tanimlar;
  final DateTime? zaman;
  final String? ustaId;

  @override
  State<_KapidanGelenFormu> createState() => _KapidanGelenFormuState();
}

class _KapidanGelenFormuState extends State<_KapidanGelenFormu> {
  static const List<int> _sureler = <int>[15, 30, 45, 60, 90];

  final TextEditingController _ad = TextEditingController();
  final TextEditingController _tel = TextEditingController();
  final TextEditingController _not = TextEditingController();
  late String _usta = widget.ustaId != null && widget.tanimlar.ustalar.any((ProUsta u) => u.id == widget.ustaId)
      ? widget.ustaId!
      : widget.tanimlar.ustalar.first.id;
  final Set<String> _hizmetler = <String>{};
  int _sureDk = 30;
  late DateTime _zaman = widget.zaman ?? _simdiYuvarla();
  bool _kaydediliyor = false;
  String? _hata;

  static DateTime _simdiYuvarla() {
    final DateTime s = DateTime.now();
    return DateTime(s.year, s.month, s.day, s.hour, s.minute - s.minute % 5);
  }

  bool get _simdi => widget.zaman == null;

  int get _toplamSure {
    if (_hizmetler.isEmpty) {
      return _sureDk;
    }
    return widget.tanimlar.hizmetler
        .where((ProHizmet h) => _hizmetler.contains(h.id))
        .fold<int>(0, (int t, ProHizmet h) => t + h.sureDk);
  }

  @override
  void dispose() {
    _ad.dispose();
    _tel.dispose();
    _not.dispose();
    super.dispose();
  }

  Future<void> _saatSec() async {
    final int? dakika = await maisonSaatSec(
      context,
      baslik: dl('Başlangıç saati', 'Start time'),
      secili: _zaman.hour * 60 + _zaman.minute,
      enCok: 1435,
      adim: 5,
    );
    if (dakika != null && mounted) {
      setState(() => _zaman = gununSaati(_zaman, dakika));
    }
  }

  Future<void> _kaydet() async {
    if (_kaydediliyor) {
      return;
    }
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final NavigatorState gezgin = Navigator.of(context);
    final ScaffoldMessengerState mesaj = ScaffoldMessenger.of(context);
    setState(() {
      _kaydediliyor = true;
      _hata = null;
    });
    try {
      final SupabaseClient i = await oturum.istemciGerekli();
      final String ad = _ad.text.trim();
      final String tel = _tel.text.trim();
      final String not = _not.text.trim();
      await i.rpc('dukkan_randevusu', params: <String, dynamic>{
        'p_salon': widget.salon.id,
        'p_usta': _usta,
        'p_baslangic': _zaman.toUtc().toIso8601String(),
        'p_hizmetler': _hizmetler.toList(),
        'p_ad': ad.isEmpty ? null : ad,
        'p_tel': tel.isEmpty ? null : tel,
        'p_not': not.isEmpty ? null : not,
        'p_sure_dk': _hizmetler.isEmpty ? _sureDk : null,
      });
      mesaj.showSnackBar(
        SnackBar(content: Text(dl(
          '${ad.isEmpty ? 'Misafir' : ad} · ${maisonSaat(_zaman)} takvime yazıldı.',
          '${ad.isEmpty ? 'Guest' : ad} · ${maisonSaat(_zaman)} added to the calendar.',
        ))),
      );
      gezgin.pop(true);
    } catch (hata) {
      if (mounted) {
        setState(() {
          _kaydediliyor = false;
          _hata = maisonHataMetni(hata);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String? hata = _hata;
    final List<ProUsta> ustalar = widget.tanimlar.ustalar;
    final List<ProHizmet> hizmetler = widget.tanimlar.hizmetler;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                _simdi ? dl('Kapıdan gelen', 'Walk-in') : dl('Randevu yaz', 'Add booking'),
                style: maisonBaslik(30, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.1),
              ),
              const SizedBox(height: 4),
              Text(
                _simdi
                    ? dl('Salona gelen müşteriyi takvime yaz; o saat müşterilere dolu görünür.', 'Add the walk-in customer to the calendar; that time will show as taken to customers.')
                    : dl('Telefonla arayan müşteri için. O saat müşterilere dolu görünür.', 'For a customer who called. That time will show as taken to customers.'),
                style: maisonGovde(13, renk: r.soluk, yukseklik: 1.45),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${maisonGun(_zaman)}, ${_zaman.day} ${maisonAy(_zaman)}',
                      style: maisonGovde(15, renk: r.yazi, kalinlik: FontWeight.w600),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _saatSec,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(maisonSaat(_zaman)),
                  ),
                ],
              ),
              if (ustalar.length > 1) ...<Widget>[
                const SizedBox(height: 16),
                MaisonUstBaslik(dl('USTA', 'BARBER')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final ProUsta u in ustalar)
                      ChoiceChip(
                        label: Text(u.ad),
                        selected: _usta == u.id,
                        onSelected: (bool _) => setState(() => _usta = u.id),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              MaisonUstBaslik(dl('HİZMET', 'SERVICE')),
              const SizedBox(height: 8),
              if (hizmetler.isEmpty)
                Text(dl('Hizmet menüsü boş; süre seçerek yazabilirsin.', 'The service menu is empty; you can add it by choosing a duration.'), style: maisonGovde(13, renk: r.soluk))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final ProHizmet h in hizmetler)
                      FilterChip(
                        label: Text('${h.ad} · ${maisonSure(h.sureDk)}'),
                        selected: _hizmetler.contains(h.id),
                        onSelected: (bool secili) => setState(() {
                          if (secili) {
                            _hizmetler.add(h.id);
                          } else {
                            _hizmetler.remove(h.id);
                          }
                        }),
                      ),
                  ],
                ),
              if (_hizmetler.isEmpty) ...<Widget>[
                const SizedBox(height: 14),
                MaisonUstBaslik(dl('SÜRE', 'DURATION')),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final int s in _sureler)
                      ChoiceChip(
                        label: Text(maisonSure(s)),
                        selected: _sureDk == s,
                        onSelected: (bool _) => setState(() => _sureDk = s),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              MaisonAlan(
                etiket: dl('MÜŞTERİ ADI (İSTEĞE BAĞLI)', 'CUSTOMER NAME (OPTIONAL)'),
                kontrol: _ad,
                ipucu: dl('Ör. Kemal Bey', 'E.g. Mr Kemal'),
                enFazla: 80,
                buyukHarf: TextCapitalization.words,
                eylem: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              MaisonAlan(
                etiket: dl('TELEFON (İSTEĞE BAĞLI)', 'PHONE (OPTIONAL)'),
                kontrol: _tel,
                ipucu: '05xx xxx xx xx',
                klavye: TextInputType.phone,
                enFazla: 20,
                eylem: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              MaisonAlan(
                etiket: dl('NOT (İSTEĞE BAĞLI)', 'NOTE (OPTIONAL)'),
                kontrol: _not,
                enFazla: 500,
                buyukHarf: TextCapitalization.sentences,
              ),
              if (hata != null) ...<Widget>[
                const SizedBox(height: 12),
                MaisonHataKutusu(hata),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _kaydediliyor ? null : _kaydet,
                  child: Text(
                    _kaydediliyor
                        ? dl('Yazılıyor…', 'Saving…')
                        : dl('Takvime yaz · ${maisonSaat(_zaman)}–${maisonSaat(_zaman.add(Duration(minutes: _toplamSure)))}', 'Add to calendar · ${maisonSaat(_zaman)}–${maisonSaat(_zaman.add(Duration(minutes: _toplamSure)))}'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mola, izin ya da kapalı saat ekler. Kaydedilirse true.
Future<bool> blokEkleAc(
  BuildContext context, {
  required TakvimTanimlari tanimlar,
  required DateTime gun,
  int? baslangic,
  String? ustaId,
}) async {
  if (tanimlar.ustalar.isEmpty) {
    return false;
  }
  final MaisonRenkler r = MaisonRenkler.of(context);
  final bool? kaydedildi = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: r.kart,
    showDragHandle: true,
    builder: (BuildContext context) =>
        _BlokFormu(tanimlar: tanimlar, gun: gun, baslangic: baslangic, ustaId: ustaId),
  );
  return kaydedildi ?? false;
}

class _BlokFormu extends StatefulWidget {
  const _BlokFormu({required this.tanimlar, required this.gun, this.baslangic, this.ustaId});

  final TakvimTanimlari tanimlar;
  final DateTime gun;
  final int? baslangic;
  final String? ustaId;

  @override
  State<_BlokFormu> createState() => _BlokFormuState();
}

class _BlokFormuState extends State<_BlokFormu> {
  static List<String> get _hazirNotlar => <String>[
        dl('Öğle arası', 'Lunch break'),
        dl('Mola', 'Break'),
        dl('İzin', 'Time off'),
        dl('Kapalı', 'Closed'),
      ];

  late String _usta = widget.ustaId != null && widget.tanimlar.ustalar.any((ProUsta u) => u.id == widget.ustaId)
      ? widget.ustaId!
      : widget.tanimlar.ustalar.first.id;
  late int _bas = widget.baslangic ?? 13 * 60;
  late int _bit = (_bas + 60).clamp(0, 1440).toInt();
  late String _not = _hazirNotlar.first;
  bool _kaydediliyor = false;
  String? _hata;

  Future<void> _saatSec({required bool bitis}) async {
    final int? dakika = await maisonSaatSec(
      context,
      baslik: bitis ? dl('Bitiş', 'End') : dl('Başlangıç', 'Start'),
      secili: bitis ? _bit : _bas,
      enAz: bitis ? _bas + 15 : 0,
      enCok: bitis ? 1440 : 1425,
    );
    if (dakika == null || !mounted) {
      return;
    }
    setState(() {
      if (bitis) {
        _bit = dakika;
      } else {
        _bas = dakika;
        if (_bit <= _bas) {
          _bit = (_bas + 60).clamp(0, 1440).toInt();
        }
      }
    });
  }

  Future<void> _kaydet() async {
    if (_kaydediliyor) {
      return;
    }
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final NavigatorState gezgin = Navigator.of(context);
    setState(() {
      _kaydediliyor = true;
      _hata = null;
    });
    try {
      final SupabaseClient i = await oturum.istemciGerekli();
      await i.rpc('blok_ekle', params: <String, dynamic>{
        'p_usta': _usta,
        'p_baslangic': gununSaati(widget.gun, _bas).toUtc().toIso8601String(),
        'p_bitis': gununSaati(widget.gun, _bit).toUtc().toIso8601String(),
        'p_not': _not,
      });
      gezgin.pop(true);
    } catch (hata) {
      if (mounted) {
        setState(() {
          _kaydediliyor = false;
          _hata = maisonHataMetni(hata);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final String? hata = _hata;
    final List<ProUsta> ustalar = widget.tanimlar.ustalar;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(dl('Mola ya da izin', 'Break or time off'), style: maisonBaslik(30, renk: r.yazi, kalinlik: FontWeight.w600, yukseklik: 1.1)),
            const SizedBox(height: 4),
            Text(
              dl('${maisonGun(widget.gun)}, ${widget.gun.day} ${maisonAy(widget.gun)} · bu aralıkta müşteri randevu alamaz.', '${maisonGun(widget.gun)}, ${widget.gun.day} ${maisonAy(widget.gun)} · customers cannot book during this time.'),
              style: maisonGovde(13, renk: r.soluk, yukseklik: 1.45),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String n in _hazirNotlar)
                  ChoiceChip(
                    label: Text(n),
                    selected: _not == n,
                    onSelected: (bool _) => setState(() => _not = n),
                  ),
              ],
            ),
            if (ustalar.length > 1) ...<Widget>[
              const SizedBox(height: 16),
              MaisonUstBaslik(dl('USTA', 'BARBER')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final ProUsta u in ustalar)
                    ChoiceChip(
                      label: Text(u.ad),
                      selected: _usta == u.id,
                      onSelected: (bool _) => setState(() => _usta = u.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _saatSec(bitis: false),
                    child: Text(dl('Başlangıç ${maisonDakikaMetni(_bas)}', 'Start ${maisonDakikaMetni(_bas)}')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _saatSec(bitis: true),
                    child: Text(dl('Bitiş ${maisonDakikaMetni(_bit)}', 'End ${maisonDakikaMetni(_bit)}')),
                  ),
                ),
              ],
            ),
            if (hata != null) ...<Widget>[
              const SizedBox(height: 12),
              MaisonHataKutusu(hata),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _kaydediliyor ? null : _kaydet,
                child: Text(_kaydediliyor ? dl('Kaydediliyor…', 'Saving…') : dl('Takvime ekle', 'Add to calendar')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
