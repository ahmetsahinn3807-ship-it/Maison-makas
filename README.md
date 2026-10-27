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
APK başka bir anahtarla imzalanmışsa derleme kırmızı biter. Bu anahtar yalnızca test içindir.

R8 küçültmesi açıktır (Google Play paketiyle aynı ayar; emülatör testi küçültülmüş APK'yı dener).
Kurallar: `apps/*/android/app/proguard-rules.pro` (eklenti sınıfları) ve `res/raw/keep.xml`
(adıyla çağrılan bildirim simgesi ve Firebase ayarları).

## Google Play paketi (AAB)

Play'e yüklenecek paketler ayrı bir iş akışıyla, elle başlatılarak derlenir:
**Actions → Google Play paketi → Run workflow**. İş akışının kaynağı `ci/play.yml`; GitHub'da
`.github/workflows/play.yml` olarak durur (zip `.github/` klasörünü açmaz, bu dosya elle eklenir).

- `ci/play.sh` iki uygulamayı `flutter build appbundle` ile derler ve **yükleme anahtarıyla** imzalar.
- Yükleme anahtarı depoda yalnız şifreli durur: `ci/play/upload.p12.gpg` (AES-256). Parolası GitHub'da
  **Settings → Secrets and variables → Actions** altında `MAISON_PLAY_PAROLA` sırrıdır; depoya yazılmaz.
  Anahtar derleme sırasında geçici bir klasöre açılır ve iş bitince silinir.
- Yükleme sertifikasının SHA-256 özeti `cf:a7:4d:21:…:2a:2e:45`; `ci/play.sh` başka bir anahtarı reddeder.
- Sürüm kodu 2026-01-01'den bu yana geçen dakikadır; her pakette büyür.
- Çıktı: **Artifacts → google-play-aab-N** (iki `.aab` ve iki `mapping.txt`). Ayrıntılar `play-raporu` dalında:
  imza, sürüm, hedef SDK, izinler, Play doğrulaması (bundletool) ve tahmini indirme boyutu.
- Aynı iş akışı her gün bir kez **sunucu nöbeti** tutar (`ci/nobet.sh`): Supabase ücretsiz planda 7 gün hiç
  kullanılmayan projeyi durdurduğu için herkese açık anahtarla tek satır okur. Yanıt gelmezse çalışma kırmızı biter.
- Google Play App Signing açık olur: Google uygulamayı kendi anahtarıyla yeniden imzalar. Yükleme anahtarı
  kaybolursa Play Console'dan yenisi istenebilir; uygulama kaybolmaz.

Mağaza görselleri `marka/` klasöründe: `play-ikon-*-512.png` (uygulama simgesi) ve
`play-tanitim-*-1024x500.png` (öne çıkan görsel; kaynakları `marka/kaynak/`).

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

### Giriş ve e-postalar

- Kayıt e-posta onayı istemez (Supabase → Authentication → Sign In / Providers → Email → **Confirm email kapalı**);
  hesap açılır açılmaz giriş yapılır. Açık bırakılırsa uygulama "onay bağlantısına dokun" der.
- **Şifremi unuttum** (giriş ekranı): e-postaya tek kullanımlık kod gider, uygulamada kod + yeni şifre yazılır
  (`resetPasswordForEmail` → `verifyOTP(type: recovery)` → `updateUser`). Bağlantıya gerek yoktur.
  Şablon: `supabase/eposta/sifre-sifirlama.html` → Authentication → Emails → **Reset password** (içinde `{{ .Token }}`).
- Supabase'in kendi e-posta servisi yalnız proje ekibine ve saatte 2 e-posta gönderir; bu yüzden
  **özel SMTP** (Gmail uygulama şifresi: `smtp.gmail.com`, port 465) tanımlıdır.

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
- **Uygulama kapalıyken bildirim** Firebase Cloud Messaging iledir (şimdilik Android):
  - Telefon, giriş yapılınca bildirim jetonunu `bildirim_jetonu_kaydet` ile hesaba yazar; çıkışta siler (0007).
  - Randevu alınınca ya da iptal edilince uygulama bildirim fonksiyonunu çağırır. Kaynağı
    `supabase/functions/randevu-bildirimi/index.ts`; Supabase'te **`smart-function`** adıyla kurulu (`MaisonPush.fonksiyon`).
    Fonksiyon kime ne gideceğini çağıranın yetkisiyle `randevu_bildirimi_hazirla`'ya sorar (her olay bir kez)
    ve Firebase'e gönderir: yeni randevu ve müşteri iptali salon sahibine ve ustaya (Makas Pro), salonun iptali
    müşteriye (Maison Makas). Metin alıcının dilindedir.
  - Fonksiyonun tek sırrı `FIREBASE_SERVICE_ACCOUNT` (Firebase hizmet hesabı JSON'u) yalnız Supabase → Edge Functions →
    Secrets'tadır; koda, depoya ve zip'e yazılmaz. Fonksiyonda "Verify JWT" kapalıdır; yetkiyi veritabanı denetler.
  - Android uygulamaları Firebase'e `android/app/src/main/res/values/firebase.xml` ile bağlanır (google-services.json'dan
    üretilir; Google Services Gradle eklentisi kullanılmaz). Bu dosya yoksa uzaktan bildirim sessizce kapalı kalır.
  - Uygulama ekrandayken bildirimi Realtime dinleyicisi gösterir; arka plandayken Firebase gösterir (çift bildirim olmaz).
  - iOS için APNs anahtarı (Apple Developer hesabı) gerekir; o zaman eklenecek.
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

## Yasal metinler (web sitesi)

`docs/` klasörü GitHub Pages ile yayımlanır (Settings → Pages → Branch: main, klasör: /docs):
https://ahmetsahinn3807-ship-it.github.io/Maison-makas/

| Sayfa | Türkçe | İngilizce |
|---|---|---|
| Gizlilik politikası | `gizlilik.html` | `privacy.html` |
| Kullanım şartları | `kosullar.html` | `terms.html` |
| KVKK aydınlatma metni | `kvkk.html` | — |
| Hesap ve veri silme (Google Play bu adresi ister) | `hesap-silme.html` | `delete-account.html` |

- Metinler taslaktır; yayından önce bir avukata gözden geçirtilmeli. `[VERİ SORUMLUSU …]` yer tutucusu doldurulacak.
- Uygulamalar bu sayfaları `MaisonBelge` ile açar (giriş ekranının altı ve Ayarlar). Site adresi `maisonSiteAdresi`'nde;
  alan adı alınırsa yalnız orası değişir.
- Uygulamada toplanan veriler değişirse (yeni bir alan, yeni bir hizmet sağlayıcı) gizlilik metni de güncellenmeli.

## Yazı tipleri

Inter ve Cormorant Garamond, SIL Open Font License 1.1 ile dağıtılır.
Lisans metinleri `packages/makas_core/lib/fonts/` içinde.
Uygulama yazı tiplerini kendi içinde taşır; açılışta internetten indirmez.
