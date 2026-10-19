/// Uygulamanın konuştuğu diller.
enum Dil {
  tr('TR'),
  en('EN'),
  de('DE');

  const Dil(this.kod);

  /// Seçicide görünen kısa kod.
  final String kod;
}

/// Ekranlardaki metinler. Tam yerelleştirme (intl) sonraki adımlarda gelecek.
class Metinler {
  const Metinler({
    required this.slogan,
    required this.aciklama,
    required this.basla,
    required this.girisYap,
    required this.isletmeSorusu,
    required this.proBilgi,
    required this.geri,
    required this.hosGeldin,
    required this.ilkDerleme,
    required this.temaBasligi,
    required this.vurguBasligi,
    required this.siradakiBaslik,
    required this.siradakiler,
  });

  final String slogan;
  final String aciklama;
  final String basla;
  final String girisYap;
  final String isletmeSorusu;
  final String proBilgi;
  final String geri;
  final String hosGeldin;
  final String ilkDerleme;
  final String temaBasligi;
  final String vurguBasligi;
  final String siradakiBaslik;
  final List<String> siradakiler;

  static Metinler dilIcin(Dil dil) {
    switch (dil) {
      case Dil.tr:
        return tr;
      case Dil.en:
        return en;
      case Dil.de:
        return de;
    }
  }

  static const Metinler tr = Metinler(
    slogan: 'Usta ellere, tek dokunuşla.',
    aciklama: 'Berberini ve kuaförünü bul, saniyeler içinde randevunu al.',
    basla: 'Hemen başla',
    girisYap: 'Hesabım var, giriş yap',
    isletmeSorusu: 'İşletme sahibi misin?',
    proBilgi: 'Maison Makas Pro, işletmeler için ayrı bir uygulamadır.',
    geri: 'Geri',
    hosGeldin: 'Hoş geldin.',
    ilkDerleme:
        'Bu ilk derleme: marka, tema ve altyapı hazır. Randevu, keşfet ve profil ekranları sıradaki adımlarda gelecek.',
    temaBasligi: 'GÖRÜNÜM',
    vurguBasligi: 'VURGU RENGİ',
    siradakiBaslik: 'Sıradaki adımlar',
    siradakiler: <String>[
      'Hesap ve giriş (Supabase)',
      'Keşfet, salon vitrini ve profil',
      'Randevu akışı ve bildirimler',
    ],
  );

  static const Metinler en = Metinler(
    slogan: 'Into master hands, with a single tap.',
    aciklama: 'Find your barber or hairdresser and book in seconds.',
    basla: 'Get started',
    girisYap: 'I have an account — sign in',
    isletmeSorusu: 'Own a salon?',
    proBilgi: 'Maison Makas Pro is a separate app for businesses.',
    geri: 'Back',
    hosGeldin: 'Welcome.',
    ilkDerleme:
        'This is the first build: brand, theme and foundations are in place. Booking, discovery and profile screens arrive in the next steps.',
    temaBasligi: 'APPEARANCE',
    vurguBasligi: 'ACCENT COLOUR',
    siradakiBaslik: 'Coming next',
    siradakiler: <String>[
      'Account and sign-in (Supabase)',
      'Discover, salon showcase and profile',
      'Booking flow and notifications',
    ],
  );

  static const Metinler de = Metinler(
    slogan: 'In Meisterhände – mit einem Fingertipp.',
    aciklama: 'Finde deinen Barbier oder Friseur und buche in Sekunden.',
    basla: 'Jetzt starten',
    girisYap: 'Ich habe ein Konto – anmelden',
    isletmeSorusu: 'Du führst einen Salon?',
    proBilgi: 'Maison Makas Pro ist eine eigene App für Salons.',
    geri: 'Zurück',
    hosGeldin: 'Willkommen.',
    ilkDerleme:
        'Dies ist der erste Build: Marke, Design und Grundlagen stehen. Termin-, Entdecken- und Profilseiten folgen in den nächsten Schritten.',
    temaBasligi: 'ERSCHEINUNGSBILD',
    vurguBasligi: 'AKZENTFARBE',
    siradakiBaslik: 'Als Nächstes',
    siradakiler: <String>[
      'Konto und Anmeldung (Supabase)',
      'Entdecken, Salon-Schaufenster und Profil',
      'Terminbuchung und Benachrichtigungen',
    ],
  );
}
