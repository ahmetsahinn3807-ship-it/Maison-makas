import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:makas_core/makas_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../gorunum.dart';
import '../hatirlatma.dart';
import '../veri.dart';
import 'ana_sayfa.dart';
import 'ayarlar_ekrani.dart';
import 'gorunum_ekrani.dart';
import 'kesfet_ekrani.dart';
import 'menu.dart';
import 'profil_ekrani.dart';
import 'randevularim_ekrani.dart';

/// Giriş yapan müşterinin ana iskeleti: soldan menü, dört sekme ve alt çubuk.
class Kabuk extends StatefulWidget {
  const Kabuk({super.key});

  @override
  State<Kabuk> createState() => _KabukState();
}

class _KabukState extends State<Kabuk> {
  final GlobalKey<ScaffoldState> _iskele = GlobalKey<ScaffoldState>();
  int _sekme = 0;
  int _randevuSekmesi = 0;
  RandevuDinleyici? _dinleyici;

  @override
  void initState() {
    super.initState();
    Veri.randevuSurumu.addListener(_hatirlatmalariKur);
    WidgetsBinding.instance.addPostFrameCallback((Duration _) => _baslat());
  }

  @override
  void dispose() {
    Veri.randevuSurumu.removeListener(_hatirlatmalariKur);
    _dinleyici?.durdur();
    super.dispose();
  }

  /// Açılışta: hatırlatmaları kurar, salonun yaptığı değişiklikleri dinlemeye başlar.
  void _baslat() {
    if (!mounted) {
      return;
    }
    final MaisonOturum oturum = OturumKapsami.oku(context);
    final String? kullanici = oturum.kullanici?.id;
    final SupabaseClient? istemci = oturum.istemci;
    if (istemci != null && kullanici != null) {
      _dinleyici = RandevuDinleyici(istemci, kullanici)..baslat();
    }
    _hatirlatmalariKur();
  }

  void _hatirlatmalariKur() {
    if (mounted) {
      RandevuHatirlatici.esitle(Veri.of(context));
    }
  }

  void _menuyuAc() => _iskele.currentState?.openDrawer();

  void _sekmeyeGit(int sekme, {int randevuSekmesi = 0}) {
    setState(() {
      _sekme = sekme;
      _randevuSekmesi = randevuSekmesi;
    });
  }

  void _ac(Widget sayfa) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (BuildContext context) => sayfa));
  }

  void _menudenSec(MenuHedefi hedef) {
    _iskele.currentState?.closeDrawer();
    switch (hedef) {
      case MenuHedefi.profil:
        _sekmeyeGit(3);
      case MenuHedefi.kesfet:
        _sekmeyeGit(1);
      case MenuHedefi.randevuYaklasan:
        _sekmeyeGit(2, randevuSekmesi: 0);
      case MenuHedefi.randevuGecmis:
        _sekmeyeGit(2, randevuSekmesi: 1);
      case MenuHedefi.beklemeListesi:
        _ac(MaisonYakindaEkrani(
          baslik: dl('Bekleme listesi', 'Waiting list'),
          ikon: Icons.hourglass_empty,
          aciklama: dl('Dolu bir saat boşalınca sıradaki müşteriye otomatik teklif edilecek.', 'When a booked slot frees up, it will be offered to the next customer automatically.'),
        ));
      case MenuHedefi.favoriler:
        _ac(MaisonYakindaEkrani(
          baslik: dl('Favorilerim', 'Favourites'),
          ikon: Icons.favorite_border,
          aciklama: dl('Beğendiğin salonları ve ustaları buraya ekleyebileceksin.', 'You will be able to save the salons and barbers you like here.'),
        ));
      case MenuHedefi.cuzdan:
        _ac(MaisonYakindaEkrani(
          baslik: dl('Cüzdan ve sadakat', 'Wallet and loyalty'),
          ikon: Icons.account_balance_wallet_outlined,
          aciklama: dl('Damga kartların, kaporaların ve hediye kesimlerin burada duracak.', 'Your stamp cards, deposits and gift cuts will live here.'),
        ));
      case MenuHedefi.mesajlar:
        _ac(MaisonYakindaEkrani(
          baslik: dl('Mesajlar', 'Messages'),
          ikon: Icons.chat_bubble_outline,
          aciklama: dl('Salonla randevun hakkında buradan yazışabileceksin.', 'You will be able to message the salon about your booking here.'),
        ));
      case MenuHedefi.gorunum:
        _ac(const GorunumEkrani());
      case MenuHedefi.ayarlar:
        _ac(const AyarlarEkrani());
    }
  }

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    final Gorunum gorunum = GorunumKapsami.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: maisonSistemCubugu(gorunum.palet),
      child: Scaffold(
        key: _iskele,
        backgroundColor: r.zemin,
        drawer: MusteriMenu(onSec: _menudenSec),
        body: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _sekme,
            children: <Widget>[
              AnaSayfa(
                menuAc: _menuyuAc,
                kesfeteGit: () => _sekmeyeGit(1),
                randevularaGit: () => _sekmeyeGit(2),
              ),
              KesfetEkrani(menuAc: _menuyuAc),
              RandevularimEkrani(menuAc: _menuyuAc, sekme: _randevuSekmesi),
              ProfilEkrani(
                menuAc: _menuyuAc,
                gorunumeGit: () => _ac(const GorunumEkrani()),
                ayarlaraGit: () => _ac(const AyarlarEkrani()),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _AltCubuk(secili: _sekme, onSec: (int i) => _sekmeyeGit(i)),
      ),
    );
  }
}

class _AltCubuk extends StatelessWidget {
  const _AltCubuk({required this.secili, required this.onSec});

  final int secili;
  final ValueChanged<int> onSec;

  static List<(IconData, IconData, String)> get _ogeler => <(IconData, IconData, String)>[
        (Icons.home_outlined, Icons.home, dl('Ana sayfa', 'Home')),
        (Icons.explore_outlined, Icons.explore, dl('Keşfet', 'Discover')),
        (Icons.calendar_month_outlined, Icons.calendar_month, dl('Randevularım', 'Bookings')),
        (Icons.person_outline, Icons.person, dl('Profil', 'Profile')),
      ];

  @override
  Widget build(BuildContext context) {
    final MaisonRenkler r = MaisonRenkler.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: r.zemin,
        border: Border(top: BorderSide(color: r.cizgi)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < _ogeler.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == secili,
                    child: InkResponse(
                      onTap: () => onSec(i),
                      radius: 36,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            i == secili ? _ogeler[i].$2 : _ogeler[i].$1,
                            size: 22,
                            color: i == secili ? r.vurgu : r.soluk,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _ogeler[i].$3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: maisonGovde(
                              11,
                              renk: i == secili ? r.vurgu : r.soluk,
                              kalinlik: i == secili ? FontWeight.w600 : FontWeight.w500,
                              yukseklik: 1.1,
                            ),
                          ),
                        ],
                      ),
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
