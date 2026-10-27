#!/usr/bin/env bash
# Maison Makas — Google Play paketi (AAB) derleme betiği.
# İş akışı (.github/workflows/play.yml) elle başlatılır: Actions → "Google Play paketi" → Run workflow.
#
# Yükleme anahtarı depoda yalnız şifreli durur (ci/play/upload.p12.gpg). Parolası GitHub Secrets'ta
# MAISON_PLAY_PAROLA adıyla saklanır; bu betik anahtarı geçici bir klasöre açar, iş bitince siler.
#
# Çıktılar:
#   cikti-play/*.aab            Play Console'a yüklenecek paketler (müşteri ve Pro)
#   cikti-play/*-mapping.txt    küçültme (R8) eşlemesi; Play Console'da "deobfuscation file" olarak yüklenebilir
#   play-raporu dalı            imza, sürüm, izin ve boyut bilgisi (Claude buradan okur)
set -euo pipefail

cd "$(dirname "$0")/.."
KOK="$(pwd)"
NO="${GITHUB_RUN_NUMBER:-1}"
# Yükleme sertifikasının SHA-256 özeti. Başka bir anahtarla imzalanan paket Play'e yüklenemez; derleme durur.
BEKLENEN_YUKLEME="cfa74d211a9bd4352b634040df384b057e6c1e6b6640d1d3ea235b5c472a2e45"
BUNDLETOOL_SURUM="1.18.3"
RAPOR="$KOK/cikti-rapor-play"
CIKTI="$KOK/cikti-play"
GIZLI="${RUNNER_TEMP:-/tmp}/maison-imza"
rm -rf "$RAPOR" "$CIKTI"
mkdir -p "$RAPOR" "$CIKTI"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

ozet() {
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    echo "$*" >> "$GITHUB_STEP_SUMMARY"
  fi
}

# Nasıl biterse bitsin: açılan anahtar silinir, rapor play-raporu dalına tek commit olarak yazılır.
bitir() {
  local durum=$?
  set +e
  rm -rf "$GIZLI"
  {
    echo "play paketi: #$NO"
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
    kayit="$(git commit-tree "$agac" -m "Play paketi #$NO raporu")"
    rm -f "$GIT_INDEX_FILE"
    git push -q -f origin "$kayit:refs/heads/play-raporu"
  ) && echo "Rapor play-raporu dalına yazıldı." || echo "::warning::Rapor dalı yazılamadı."
  exit "$durum"
}
trap bitir EXIT

ozet "## Google Play paketi — #$NO"
ozet ""

# 1) Yükleme anahtarını aç
if [ -z "${MAISON_PLAY_PAROLA:-}" ]; then
  ozet "**Parola eksik:** GitHub'da Settings → Secrets and variables → Actions → New repository secret ile"
  ozet "\`MAISON_PLAY_PAROLA\` adında bir sır ekleyin (değeri Claude'un verdiği parola)."
  echo "::error::MAISON_PLAY_PAROLA sırrı tanımlı değil."
  echo "MAISON_PLAY_PAROLA tanimli degil" > "$RAPOR/01-anahtar.txt"
  exit 1
fi
rm -rf "$GIZLI"
mkdir -p "$GIZLI"
chmod 700 "$GIZLI"
if ! gpg --batch --quiet --pinentry-mode loopback --passphrase "$MAISON_PLAY_PAROLA" \
  -o "$GIZLI/upload.p12" -d ci/play/upload.p12.gpg 2> "$RAPOR/01-anahtar.txt"; then
  ozet "**Parola yanlış:** \`MAISON_PLAY_PAROLA\` sırrı anahtarı açamadı. Sırrı silip parolayı yeniden yapıştırın."
  echo "::error::Yükleme anahtarı açılamadı (parola yanlış)."
  exit 1
fi
parmak="$(keytool -list -v -keystore "$GIZLI/upload.p12" -storetype pkcs12 -storepass "$MAISON_PLAY_PAROLA" -alias upload 2>/dev/null \
  | grep -m1 'SHA256:' | sed 's/.*SHA256: //' | tr -d ':[:space:]' | tr 'A-F' 'a-f' || true)"
echo "yukleme sertifikasi SHA-256: $parmak" >> "$RAPOR/01-anahtar.txt"
if [ "$parmak" != "$BEKLENEN_YUKLEME" ]; then
  ozet "**Anahtar beklenen anahtar değil** (${parmak:0:8}…, beklenen ${BEKLENEN_YUKLEME:0:8}…)."
  echo "::error::Yükleme anahtarı beklenen anahtar değil."
  exit 1
fi
export MAISON_UPLOAD_STORE_FILE="$GIZLI/upload.p12"
export MAISON_UPLOAD_PASSWORD="$MAISON_PLAY_PAROLA"
echo "Yükleme anahtarı hazır (${parmak:0:8}…)."

# 2) NDK: Flutter'ın istediği sürüm önceden ve yeniden denenerek kurulur (ci/derle.sh ile aynı).
SDK="${ANDROID_HOME:-/usr/local/lib/android/sdk}"
NDK_SURUM="$(grep -ho 'ndkVersion: String = "[^"]*"' \
  "${FLUTTER_ROOT:-/yok}/packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt" 2>/dev/null \
  | sed 's/.*= "//; s/"$//' | head -1 || true)"
NDK_SURUM="${NDK_SURUM:-28.2.13676358}"
ndk_kur() {
  local sdkm="$SDK/cmdline-tools/latest/bin/sdkmanager" deneme
  if [ -f "$SDK/ndk/$NDK_SURUM/source.properties" ]; then
    return 0
  fi
  if [ ! -x "$sdkm" ]; then
    return 0
  fi
  for deneme in 1 2 3; do
    rm -rf "$SDK/.temp" "$SDK/.downloadIntermediates" "$SDK/ndk/$NDK_SURUM" 2>/dev/null || true
    if "$sdkm" --install "ndk;$NDK_SURUM" < /dev/null > "$RAPOR/02-ndk-deneme-$deneme.txt" 2>&1 \
      && [ -f "$SDK/ndk/$NDK_SURUM/source.properties" ]; then
      return 0
    fi
    sleep 15
  done
  local yedek
  yedek="$(ls -1 "$SDK/ndk" 2>/dev/null | sort -V | tail -1 || true)"
  if [ -n "$yedek" ] && [ -f "$SDK/ndk/$yedek/source.properties" ]; then
    export ORG_GRADLE_PROJECT_maisonNdk="$yedek"
    echo "::warning::NDK $NDK_SURUM kurulamadı; makinedeki NDK $yedek kullanılacak."
  fi
  return 0
}
echo "::group::NDK"
ndk_kur
echo "::endgroup::"

# 3) Sürüm kodu: 2026-01-01'den bu yana geçen dakika. Her pakette büyür; Play aynı kodu iki kez kabul etmez.
KOD=$(( ( $(date -u +%s) - $(date -u -d 2026-01-01 +%s) ) / 60 ))
echo "sürüm kodu: $KOD"

GECICI_HATA='Error on ZipFile|unknown archive|Could not GET|Could not HEAD|Could not download|Connection reset|Read timed out|Connect timed out|Failed to install the following|Remote host terminated|received status code 5[0-9][0-9]'

paketle() {
  local dizin="$1" dosya="$2" surum deneme
  surum="$(sed -n 's/^version: *\([0-9.]*\).*/\1/p' "apps/$dizin/pubspec.yaml")"
  echo "::group::$dizin — AAB"
  for deneme in 1 2; do
    if (
      cd "apps/$dizin"
      flutter pub get > "$RAPOR/$dizin-1-pub.txt" 2>&1
      flutter build appbundle --release --build-number="$KOD" 2>&1 | tee "$RAPOR/$dizin-2-aab.txt"
    ); then
      break
    fi
    if [ "$deneme" = 1 ] && grep -qE "$GECICI_HATA" "$RAPOR/$dizin-2-aab.txt"; then
      echo "::warning::$dizin: indirme yarıda kaldı; bir kez daha deneniyor."
      mv "$RAPOR/$dizin-2-aab.txt" "$RAPOR/$dizin-2-aab-deneme1.txt"
      ndk_kur
      continue
    fi
    echo "::error::$dizin: AAB derlenemedi (ayrıntı play-raporu dalında: $dizin-2-aab.txt)."
    return 1
  done
  cp "apps/$dizin/build/app/outputs/bundle/release/app-release.aab" "$CIKTI/$dosya-$surum-$KOD.aab"
  local esleme="apps/$dizin/build/app/outputs/mapping/release/mapping.txt"
  if [ -f "$esleme" ]; then
    cp "$esleme" "$CIKTI/$dosya-$surum-$KOD-mapping.txt"
  else
    echo "::warning::$dizin: mapping.txt yok (küçültme kapalı mı?)."
  fi
  echo "::endgroup::"
}
paketle musteri maison-makas
paketle pro makas-pro
rm -rf "$GIZLI"

# 4) Denetim: imza, manifest (sürüm, hedef SDK, izinler), Play'in kendi doğrulaması ve indirme boyutu.
echo "::group::Denetim"
BT="${RUNNER_TEMP:-/tmp}/bundletool.jar"
if ! curl -fsSL --retry 3 -o "$BT" \
  "https://github.com/google/bundletool/releases/download/$BUNDLETOOL_SURUM/bundletool-all-$BUNDLETOOL_SURUM.jar"; then
  echo "::warning::bundletool indirilemedi; manifest denetimi atlanıyor."
  BT=""
fi
hata=0
ozet "| Paket | Sürüm | Hedef SDK | Boyut | İndirme (en çok) | İmza |"
ozet "|---|---|---|---|---|---|"
for aab in "$CIKTI"/*.aab; do
  ad="$(basename "$aab")"
  imza="$(keytool -printcert -jarfile "$aab" 2>/dev/null | grep -m1 'SHA256:' | sed 's/.*SHA256: //' | tr -d ':[:space:]' | tr 'A-F' 'a-f' || true)"
  if [ "$imza" = "$BEKLENEN_YUKLEME" ]; then
    imza_durum="✓ yükleme anahtarı"
  else
    imza_durum="✗ ${imza:0:8}"
    hata=1
  fi
  boyut="$(du -m "$aab" | cut -f1) MB"
  surum="?"; hedef="?"; indirme="?"
  {
    echo "== $ad"
    echo "imza SHA-256: $imza"
    if [ -n "$BT" ]; then
      manifest="$(java -jar "$BT" dump manifest --bundle "$aab" 2>&1 || true)"
      kod="$(echo "$manifest" | grep -o 'android:versionCode="[0-9]*"' | head -1 | grep -o '[0-9]*' || true)"
      isim="$(echo "$manifest" | grep -o 'android:versionName="[^"]*"' | head -1 | sed 's/.*="//; s/"$//' || true)"
      hedef="$(echo "$manifest" | grep -o 'android:targetSdkVersion="[0-9]*"' | head -1 | grep -o '[0-9]*' || true)"
      enaz="$(echo "$manifest" | grep -o 'android:minSdkVersion="[0-9]*"' | head -1 | grep -o '[0-9]*' || true)"
      surum="$isim ($kod)"
      echo "paket: $(echo "$manifest" | grep -o 'package="[^"]*"' | head -1)"
      echo "surum: $surum · minSdk $enaz · targetSdk $hedef"
      echo "izinler:"
      echo "$manifest" | grep -o 'uses-permission[^>]*android:name="[^"]*"' | sed 's/.*android:name="/  /; s/"$//' | sort -u
      echo "debuggable: $(echo "$manifest" | grep -c 'android:debuggable="true"' || true)"
      echo "dogrulama:"
      java -jar "$BT" validate --bundle "$aab" 2>&1 | tail -5 | sed 's/^/  /' || true
      apks="${RUNNER_TEMP:-/tmp}/$ad.apks"
      if java -jar "$BT" build-apks --bundle "$aab" --output "$apks" --overwrite > /dev/null 2>&1; then
        boyutlar="$(java -jar "$BT" get-size total --apks "$apks" 2>/dev/null | tail -1 || true)"
        echo "indirme boyutu (MIN,MAX bayt): $boyutlar"
        enbuyuk="$(echo "$boyutlar" | cut -d, -f2)"
        if [[ "$enbuyuk" =~ ^[0-9]+$ ]]; then indirme="$(( enbuyuk / 1048576 )) MB"; fi
      fi
      if [[ "$hedef" =~ ^[0-9]+$ ]] && [ "$hedef" -lt 35 ]; then
        echo "UYARI: hedef SDK 35'ten düşük; Play yeni uygulamayı kabul etmez."
        hata=1
      fi
    fi
    echo
  } >> "$RAPOR/03-aab-bilgi.txt" 2>&1
  echo "$ad → $surum, $boyut, imza $imza_durum"
  ozet "| $ad | $surum | ${hedef:-?} | $boyut | $indirme | $imza_durum |"
done
ls -la "$CIKTI" | tee "$RAPOR/04-dosyalar.txt"
echo "::endgroup::"
ozet ""
ozet "Paketler aşağıdaki **Artifacts** bölümünde: \`google-play-aab-$NO\`. Play Console → Test ve yayın → yeni sürüm → AAB yükle."
if [ "$hata" = 1 ]; then
  echo "::error::Denetim başarısız (ayrıntı play-raporu dalında: 03-aab-bilgi.txt)."
  exit 1
fi
