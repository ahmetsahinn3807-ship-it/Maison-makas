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

Her APK `ci/debug.keystore` ile imzalanır; bu sayede yeni sürüm eskisini kaldırmadan üstüne kurulur.
Bu anahtar yalnızca test içindir. Google Play'e yükleme için ayrı bir yükleme anahtarı oluşturulacak (rehberde 13. adım).

Bir dosyayı silmek gerektiğinde, zip içine `ci/silinecekler.txt` konur (her satıra bir yol).

## Yazı tipleri

Inter ve Cormorant Garamond, SIL Open Font License 1.1 ile dağıtılır.
Lisans metinleri `packages/makas_core/lib/fonts/` içinde.
Uygulama yazı tiplerini kendi içinde taşır; açılışta internetten indirmez.
