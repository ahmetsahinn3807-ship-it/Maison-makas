#!/usr/bin/env bash
# Maison Makas — GitHub Actions derleme betiği.
# İş akışı (.github/workflows/android.yml) Flutter'ı kurduktan sonra bunu çalıştırır.
#
# Çıktılar:
#   cikti/*.apk                 indirilecek APK'lar
#   çalışma özeti               Actions'ta derlemenin sayfasında görünen tablo
#   derleme-raporu dalı         analiz, test, imza ve emülatör sonuçları (Claude buradan okur)
set -euo pipefail

cd "$(dirname "$0")/.."
KOK="$(pwd)"
NO="${GITHUB_RUN_NUMBER:-1}"
DAL="${GITHUB_REF_NAME:-main}"
# ci/debug.keystore sertifikasının SHA-256 özeti. APK başka bir anahtarla imzalanırsa derleme durur.
BEKLENEN_IMZA="0ae9d325ce773b7df4bde176184cc86fbab4c4ebc08db9acfadc81396f5776f9"
RAPOR="$KOK/cikti-rapor"
rm -rf "$RAPOR"
mkdir -p "$RAPOR" cikti

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

ozet() {
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    echo "$*" >> "$GITHUB_STEP_SUMMARY"
  fi
}

# Derleme nasıl biterse bitsin rapor, ayrı bir dala (derleme-raporu) tek commit olarak yazılır.
# main dalına dokunmaz; o dala gönderim yeni derleme başlatmaz.
rapor_gonder() {
  local durum=$?
  set +e
  {
    echo "derleme: #$NO"
    if [ "$durum" -eq 0 ]; then echo "durum: basarili"; else echo "durum: HATA (cikis kodu $durum)"; fi
    echo "tarih: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "commit: ${GITHUB_SHA:-?}"
  } > "$RAPOR/00-durum.txt"
  (
    GIT_INDEX_FILE="$(mktemp -u)"
    export GIT_INDEX_FILE
    git read-tree --empty
    for f in "$RAPOR"/*; do
      [ -f "$f" ] || continue
      git update-index --add --cacheinfo "100644,$(git hash-object -w "$f"),$(basename "$f")"
    done
    agac="$(git write-tree)"
    kayit="$(git commit-tree "$agac" -m "Derleme #$NO raporu")"
    rm -f "$GIT_INDEX_FILE"
    git push -q -f origin "$kayit:refs/heads/derleme-raporu"
  ) && echo "Rapor derleme-raporu dalına yazıldı." || echo "::warning::Rapor dalı yazılamadı."
  exit "$durum"
}
trap rapor_gonder EXIT

echo "::group::Flutter sürümü"
flutter --version 2>&1 | tee "$RAPOR/01-flutter.txt"
echo "::endgroup::"

# 1) Platform klasörleri (yalnızca ilk sefer üretilir ve depoya yazılır)
echo "::group::İlk kurulum"
bash ci/ilk-kurulum.sh
if [ -n "$(git status --porcelain -- apps)" ]; then
  git add -A apps
  git commit -q -m "Android ve iOS platform klasörleri oluşturuldu [skip ci]"
  if git push -q origin "HEAD:$DAL"; then
    echo "Platform klasörleri depoya yazıldı."
  else
    echo "::warning::Platform klasörleri depoya yazılamadı; derleme yine de sürüyor."
  fi
fi
echo "::endgroup::"

# 2) İmza: apps/*/android/app/build.gradle.kts doğrudan ci/debug.keystore'u kullanır.
#    Varsayılan konuma da kopyalanır; Gradle'ın kendi anahtar üretmesine gerek kalmaz.
for d in "${ANDROID_USER_HOME:-}" "$HOME/.android"; do
  [ -n "$d" ] || continue
  mkdir -p "$d"
  cp ci/debug.keystore "$d/debug.keystore"
done

# 3) Analiz, test ve APK
derle() {
  local dizin="$1" dosya="$2"
  echo "::group::$dizin — analiz ve test"
  (
    cd "apps/$dizin"
    flutter pub get 2>&1 | tee "$RAPOR/$dizin-1-pub.txt"
    flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tee "$RAPOR/$dizin-2-analiz.txt" \
      || echo "::warning::$dizin: analizde hata bulundu (yukarıdaki satırlara bakın)."
    flutter test 2>&1 | tee "$RAPOR/$dizin-3-test.txt" \
      || echo "::warning::$dizin: testler geçmedi (yukarıdaki satırlara bakın)."
  )
  echo "::endgroup::"
  echo "::group::$dizin — APK"
  (
    cd "apps/$dizin"
    flutter build apk --release --build-number="$NO" 2>&1 | tee "$RAPOR/$dizin-4-apk.txt"
  )
  cp "apps/$dizin/build/app/outputs/flutter-apk/app-release.apk" "cikti/$dosya-$NO.apk"
  echo "::endgroup::"
}
derle musteri maison-makas
derle pro makas-pro

# 4) İmza ve paket bilgisi. İmza beklenen anahtar değilse derleme durur:
#    öyle bir APK telefonda eski sürümün üstüne kurulmaz.
echo "::group::İmza ve paket bilgisi"
ARAC="$(ls -d "${ANDROID_HOME:-/usr/local/lib/android/sdk}"/build-tools/*/ 2>/dev/null | sort -V | tail -1 || true)"
imza_hatali=0
imza_denetimi=1
if [ -z "$ARAC" ] || [ ! -x "${ARAC}apksigner" ]; then
  echo "::warning::apksigner bulunamadı; imza denetlenemedi."
  imza_denetimi=0
fi
ozet "## Maison Makas — derleme #$NO"
ozet ""
ozet "| APK | Sürüm | Boyut | İmza |"
ozet "|---|---|---|---|"
for apk in cikti/*.apk; do
  imza="$("${ARAC}apksigner" verify --print-certs "$apk" 2>/dev/null | grep -m1 'SHA-256 digest' | sed 's/.*digest: //' | tr -d '[:space:]' || true)"
  ilk="$("${ARAC}aapt2" dump badging "$apk" 2>/dev/null | head -1 || true)"
  kod="$(echo "$ilk" | sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p")"
  ad="$(echo "$ilk" | sed -n "s/.*versionName='\([^']*\)'.*/\1/p")"
  boyut="$(du -m "$apk" | cut -f1) MB"
  if [ "$imza_denetimi" = 0 ]; then
    imza_durum="? (denetlenemedi)"
  elif [ "$imza" = "$BEKLENEN_IMZA" ]; then
    imza_durum="✓ ${imza:0:8}"
  else
    imza_durum="✗ ${imza:0:8} (beklenen ${BEKLENEN_IMZA:0:8})"
    imza_hatali=1
  fi
  echo "$apk → sürüm $ad ($kod), $boyut, imza $imza_durum"
  ozet "| $(basename "$apk") | $ad ($kod) | $boyut | $imza_durum |"
  {
    echo "== $apk"
    echo "imza: $imza"
    "${ARAC}aapt2" dump badging "$apk" 2>/dev/null \
      | grep -E "^(package|sdkVersion|targetSdkVersion|uses-permission|native-code|application-label):" || true
    tmp="$(mktemp -d)"
    unzip -q -o "$apk" 'classes*.dex' -d "$tmp" 2>/dev/null || true
    if grep -qa "GeneratedPluginRegistrant" "$tmp"/classes*.dex 2>/dev/null; then
      echo "eklenti kaydı (GeneratedPluginRegistrant): var"
    else
      echo "eklenti kaydı (GeneratedPluginRegistrant): YOK"
    fi
    rm -rf "$tmp"
    echo
  } >> "$RAPOR/05-apk-bilgi.txt"
done
{
  echo "ANDROID_USER_HOME=${ANDROID_USER_HOME:-}"
  echo "ANDROID_SDK_HOME=${ANDROID_SDK_HOME:-}"
  echo "ANDROID_PREFS_ROOT=${ANDROID_PREFS_ROOT:-}"
  echo "HOME=$HOME"
  find "$HOME" -maxdepth 4 -name 'debug.keystore' 2>/dev/null | head -20
  find "$KOK/apps" /tmp -name 'debug.keystore' 2>/dev/null | head -20
} > "$RAPOR/06-imza-teshis.txt"
ls -la cikti
echo "::endgroup::"
for d in musteri pro; do
  analiz="$(grep -E 'issues? found|No issues found' "$RAPOR/$d-2-analiz.txt" 2>/dev/null | tail -1 || true)"
  test_sonuc="$(grep -E 'tests? passed|Some tests failed|tests? failed' "$RAPOR/$d-3-test.txt" 2>/dev/null | tail -1 || true)"
  ozet ""
  ozet "**$d** — analiz: ${analiz:-?} · test: ${test_sonuc:-?}"
done
if [ "$imza_hatali" = 1 ]; then
  ozet ""
  ozet "**İmza hatalı:** APK ci/debug.keystore ile imzalanmamış; telefonda eski sürümün üstüne kurulmaz."
  echo "::error::APK beklenen anahtarla imzalanmamış (beklenen ${BEKLENEN_IMZA:0:8}…)."
  exit 1
fi

# 5) Emülatör duman testi: APK'ları açar, giriş ekranından sunucuya bir deneme yapar.
#    Derlemeyi hiçbir zaman durdurmaz; sonuç rapora ve özete yazılır.
if [ -f ci/emulator-testi.sh ]; then
  echo "::group::Emülatör duman testi"
  timeout 1500 bash ci/emulator-testi.sh "$RAPOR" || echo "::warning::Emülatör testi tamamlanamadı."
  if [ -f "$RAPOR/07-duman-ozet.txt" ]; then
    ozet ""
    ozet "**Emülatör testi**"
    while IFS= read -r satir; do ozet "- $satir"; done < "$RAPOR/07-duman-ozet.txt"
  fi
  echo "::endgroup::"
fi
