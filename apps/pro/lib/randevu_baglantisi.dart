/// Müşterinin salonun randevu sayfasına giden adres. Sayfa GitHub Pages üzerinde çalışır;
/// salon, kısa adıyla (`?s=`) seçilir. Sayfa: docs/randevu/index.html.
const String randevuSayfaTabani = 'https://ahmetsahinn3807-ship-it.github.io/Maison-makas/randevu/?s=';

/// Salonun kısa adından (ör. "maison-sahin") randevu bağlantısı üretir.
String randevuBaglantisi(String kisaAd) => '$randevuSayfaTabani$kisaAd';
