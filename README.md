# Maison Makas

Berber ve kuaförler için randevu sistemi. İki uygulama, tek tasarım sistemi:

| Uygulama | Klasör | Paket adı | Kimin için |
|---|---|---|---|
| **Maison Makas** | `apps/musteri` | `com.maisonmakas.musteri` | Müşteriler: salon bul, randevu al |
| **Makas Pro** | `apps/pro` | `com.maisonmakas.pro` | Salon sahipleri ve ustalar |

Ortak renkler, tema, yazı tipleri ve amblem `packages/makas_core` içinde.

## Klasörler

```
apps/musteri        Müşteri uygulaması (Flutter)
apps/pro            İşletme uygulaması (Flutter)
packages/makas_core Paletler (5 görünüm), tema, Inter + Cormorant Garamond, amblem çizimi
marka/              Logo SVG'leri, Play (512) ve App Store (1024) ikonları
ci/                 GitHub Actions betikleri ve test imza anahtarı
```

## Derleme nasıl çalışır?

1. Proje zip olarak depoya yüklenir (Add file → Upload files).
2. GitHub Actions zip'i açar, dosyaları depoya yerleştirir ve zip'i siler.
3. İlk seferde `flutter create` ile `android/` ve `ios/` klasörleri üretilir ve depoya yazılır.
   Depodaki ikonlar ve açılış renkleri korunur.
4. Her iki uygulama analiz edilir, test edilir ve APK olarak derlenir.
5. APK'lar **Actions → son çalışma → Artifacts → maison-makas-apk-N** altından indirilir.

Her APK `ci/debug.keystore` ile imzalanır (`apps/*/android/app/build.gradle.kts` içindeki `maisonTest` ayarı);
bu sayede yeni sürüm eskisini kaldırmadan üstüne kurulur. `ci/derle.sh` imzanın SHA-256 özetini denetler;
APK başka bir anahtarla imzalanmışsa derleme kırmızı biter. Bu anahtar yalnızca test içindir; Google Play'e
yükleme için ayrı bir yükleme anahtarı oluşturulacak (rehberde 13. adım).

Test derlemelerinde R8 küçültmesi kapalıdır (`apps/*/android/gradle.properties` → `shrink=false`).
Google Play'den önce yeniden açılacak; eklentiler için kurallar `apps/*/android/app/proguard-rules.pro` içinde hazır.

### Derleme raporu

Her derlemenin sonunda:

- Actions'ta derlemenin sayfasında kısa bir özet tablosu görünür (sürüm, boyut, imza, analiz, test, emülatör).
- Ayrıntılar `derleme-raporu` dalına tek commit olarak yazılır: Flutter sürümü, `flutter analyze` ve
  `flutter test` çıktıları, APK bilgileri, emülatör ekran görüntüleri ve logcat. Bu dal derleme başlatmaz.

### Emülatör duman testi

`ci/emulator-testi.sh` iki APK'yı bir Android emülatöründe açar, giriş ekranına geçer ve yanlış bir şifreyle
giriş dener. "E-posta ya da şifre hatalı" yanıtı gelirse uygulama sunucuya ulaşabiliyor demektir.
Hesap açmaz, veritabanına yazmaz, derlemeyi hiçbir zaman durdurmaz. Kapatmak için betiği silmek yeter.

### iOS derleme denetimi

`.github/workflows/ios.yml` (elle başlatılır: Actions → iOS derleme denetimi → Run workflow) iki uygulamayı macOS'ta
imzasız derler (`ci/ios-denetim.sh`). Apple hesabı ya da iPhone gerekmez; iOS tarafında derleme hatası olmadığını gösterir.
Sonuç `ios-raporu` dalına yazılır. Depo gizliyse macOS dakikaları ücretsiz kotadan katlı düşer; bu yüzden her yüklemede değil,
iOS'u etkileyen bir değişiklikten sonra başlatılır.

- iOS'ta bildirimler için `AppDelegate.swift` içinde `UNUserNotificationCenter` temsilcisi ayarlıdır.
- `Info.plist`: kamera ve fotoğraf izin metinleri (Türkçe), desteklenen diller `tr`, `en`.
- TestFlight'a gönderim (Codemagic + App Store Connect API anahtarı) Apple Developer hesabı ve bir iPhone olunca eklenecek.

Bir dosyayı silmek gerektiğinde, zip içine `ci/silinecekler.txt` konur (her satıra bir yol).

## Sunucu (Supabase)

Hesaplar, salonlar ve randevular Supabase'te durur (proje: `fhxwtfefinoaetlpxbpr`).

- `supabase/migrations/` içindeki SQL dosyaları **tarih sırasıyla** Supabase → SQL Editor'da çalıştırılır.
  Her dosya bir kez çalıştırılır; `20261019210000_uygulama_fonksiyonlari.sql` ve sonrakiler tekrar çalışsa da zarar vermez.
- Uygulamalar yalnız **publishable** anahtarı kullanır (`packages/makas_core/lib/src/supabase_ayar.dart`).
  Bu anahtar herkese açık olabilir; verileri tablolardaki güvenlik kuralları (RLS) korur.
- **Secret anahtar (`sb_secret_…`) ve veritabanı şifresi hiçbir zaman koda, zip'e ya da sohbete yazılmaz.**
- `supabase/test/` yerel PostgreSQL'de çalışan testlerdir; gerçek projede çalıştırılmaz.
- Randevu yalnız `randevu_al` fonksiyonuyla alınır; aynı ustaya çakışan iki randevu veritabanı düzeyinde engellenir.
- Hesap silme uygulama içindedir (`hesabimi_sil`). Salon sahibi Makas Pro'dan salonuyla birlikte siler;
  yaklaşan randevusu olan salon silinmez.

### Ekip ve çalışma saatleri

- Hizmetler, ustalar ve haftalık saatler Makas Pro'dan yönetilir. Saatler `usta_saatlerini_kaydet` ile
  tek seferde yazılır (çakışan aralık reddedilir); boş saatler `bos_saatler` bu tablodan hesaplanır.
- Bir ustanın yaptığı hizmetler `usta_hizmet` tablosundadır; liste boşsa usta bütün hizmetleri yapar.
- Bir hesap ekibe yalnız **davet koduyla** bağlanır (`usta_davet_kodu_olustur` → `usta_davetini_kabul_et`).
  Kod 7 gün geçerli ve tek kullanımlıktır; veritabanında yalnız SHA-256 özeti saklanır.
  Salon sahibi kendini "Kendimi ekibe ekle" ile bağlar.

### Randevu ve takvim

- Müşteri boş saatleri `musait_saatler` ile görür: seçtiği hizmetlerin toplam süresi, o hizmetleri yapan
  ustalar, çalışma saatleri, mevcut randevular, molalar ve salonun hazırlık süresi hesaba katılır (15 dakikalık adımlar).
- Randevu `randevu_al` ile alınır; çakışan iki randevu veritabanında yazılamaz.
- Makas Pro'da kapıdan gelen ya da telefonla arayan müşteri `dukkan_randevusu`, mola ve izin `blok_ekle` ile yazılır;
  geldi / gelmedi işareti `randevu_durumu`, iptal `randevu_iptal` iledir.

### Bildirimler

- **Hatırlatmalar** müşterinin telefonunda zamanlanır (`flutter_local_notifications`): her yaklaşan randevu için
  24 saat ve 2 saat önce. Sunucu gerekmez, uygulama kapalıyken de gelir. Randevu alınınca, iptal edilince ve
  uygulama açılınca liste baştan kurulur. Ayarlar → Bildirimler'den kapatılabilir (telefonda saklanır).
  Android pil tasarrufu nedeniyle birkaç dakika kayabilir.
- **Canlı güncelleme** Supabase Realtime iledir (`randevular` tablosu `supabase_realtime` yayınında, 0006).
  RLS geçerlidir: herkes yalnız görmeye yetkili olduğu satırların değişikliğini alır.
  - Makas Pro açıkken: müşteri uygulamadan randevu alır ya da iptal ederse liste anında yenilenir ve uyarı çıkar.
  - Maison Makas açıkken: salon randevuyu iptal ederse müşteriye bildirim gelir.
- Uygulamalar tamamen kapalıyken anlık bildirim (Firebase push) mağaza yayınından önce eklenecek.
- Android'de zamanlanmış bildirimler için `AndroidManifest.xml` alıcıları ve `build.gradle.kts` içinde
  core library desugaring gerekir; ikisi de projede hazır.

### Fotoğraflar

- İki herkese açık kova: `profil` (müşterinin profil ve kapak fotoğrafı, `profil/<kullanıcı>/…`) ve
  `salon` (kapak, logo ve galeri, `salon/<salon>/…`). Bir klasöre yalnız sahibi yükler ve oradan yalnız sahibi siler.
- Fotoğraf telefonda küçültülür (kapak 1600, galeri 1440, profil ve logo 640 piksel) ve en çok 6 MB olabilir.
- Kapakta görünecek kısım `kapak_odak_x/y` (0–1) olarak saklanır; vitrin filtresi (`salonlar.vitrin.filtre`)
  fotoğrafın kendisini değiştirmez, gösterilirken uygulanır.
- Storage dosyaları SQL ile silinemez; uygulama eski dosyayı Storage API ile siler, hesap silinirken klasörleri boşaltır.

## Dil ve görünüm

- İki uygulama Türkçe ve İngilizcedir. Metinler kodun içinde yan yana yazılır: `dl('Kaydet', 'Save')`
  (`packages/makas_core/lib/src/dil.dart`). Yeni bir ekran metni eklerken ikisi birlikte yazılır.
- Seçili dil `MaisonTercih.dil` içindedir ve telefonda saklanır. İlk açılışta telefonun dili Türkçe değilse İngilizce açılır.
  Giriş yapılınca dil hesaba (`profiller.dil`) yazılır; yeni bir telefonda hesaptaki dil uygulanır.
- Tarih, gün adı, para (₺1,250 / 1.250 ₺), süre ve ondalık biçimleri seçili dile uyar (`tarih.dart`).
- Sunucu hata mesajlarını Türkçe yazar; İngilizcesi `sunucu_mesajlari.dart` içindedir. Yeni bir SQL mesajı eklenince
  buraya da eklenmeli: `apps/musteri/test/dil_test.dart` her `raise exception` mesajının çevirisi olduğunu denetler.
- Yazı boyutu (Küçük / Normal / Büyük) telefonun kendi yazı boyutunun üstüne uygulanır ve telefonda saklanır.
- Maison Makas'ta tema (5 palet), vurgu rengi ve koyu mod hesaba kaydedilir. Makas Pro'da koyu görünüm telefonda saklanır.

## Yazı tipleri

Inter ve Cormorant Garamond, SIL Open Font License 1.1 ile dağıtılır.
Lisans metinleri `packages/makas_core/lib/fonts/` içinde.
Uygulama yazı tiplerini kendi içinde taşır; açılışta internetten indirmez.
