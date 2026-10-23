#!/usr/bin/env bash
# Maison Makas — iOS derleme denetimi (imzasız).
# İş akışı (.github/workflows/ios.yml) macOS üzerinde Flutter'ı kurduktan sonra bunu çalıştırır.
# Apple hesabı ya da iPhone gerekmez: iki uygulamanın iOS için derlenebildiğini gösterir.
# Uygulamayı telefona kurmak (TestFlight) için Apple Developer hesabı ve imza gerekir; o ayrı adım.
#
# Çıktılar:
#   çalışma özeti         Actions'ta görünen kısa tablo
#   ios-raporu dalı       derleme çıktıları (Claude buradan okur)
set -euo pipefail

cd "$(dirname "$0")/.."
KOK="$(pwd)"
NO="${GITHUB_RUN_NUMBER:-1}"
RAPOR="$KOK/ios-rapor"
rm -rf "$RAPOR"
mkdir -p "$RAPOR"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

ozet() {
  if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
    echo "$*" >> "$GITHUB_STEP_SUMMARY"
  fi
}

rapor_gonder() {
  local durum=$?
  set +e
  {
    echo "ios denetimi: #$NO"
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
    kayit="$(git commit-tree "$agac" -m "iOS denetimi #$NO raporu")"
    rm -f "$GIT_INDEX_FILE"
    git push -q -f origin "$kayit:refs/heads/ios-raporu"
  ) && echo "Rapor ios-raporu dalına yazıldı." || echo "::warning::Rapor dalı yazılamadı."
  exit "$durum"
}
trap rapor_gonder EXIT

{
  flutter --version 2>&1
  echo
  xcodebuild -version 2>&1
  echo
  pod --version 2>&1 | sed 's/^/CocoaPods /'
} | tee "$RAPOR/01-surumler.txt"

ozet "### iOS derleme denetimi #$NO"
ozet ""
ozet "| Uygulama | Sonuç |"
ozet "|---|---|"

hata=0
for dizin in musteri pro; do
  echo "::group::$dizin: iOS derleniyor"
  if [ ! -f "apps/$dizin/ios/Runner.xcodeproj/project.pbxproj" ]; then
    echo "iOS klasörü yok (önce Android derlemesi bir kez çalışmalı)." | tee "$RAPOR/$dizin-ios.txt"
    ozet "| $dizin | iOS klasörü yok |"
    hata=1
    echo "::endgroup::"
    continue
  fi
  set +e
  (cd "apps/$dizin" && flutter pub get && flutter build ios --release --no-codesign) > "$RAPOR/$dizin-ios.txt" 2>&1
  kod=$?
  set -e
  tail -n 40 "$RAPOR/$dizin-ios.txt"
  echo "::endgroup::"
  if [ "$kod" -eq 0 ]; then
    boyut="$(du -sh "apps/$dizin/build/ios/iphoneos/Runner.app" 2>/dev/null | cut -f1)"
    echo "$dizin: derlendi ($boyut)" >> "$RAPOR/02-ozet.txt"
    ozet "| $dizin | ✅ derlendi ($boyut) |"
  else
    echo "$dizin: DERLENEMEDİ" >> "$RAPOR/02-ozet.txt"
    ozet "| $dizin | ❌ derlenemedi |"
    echo "::error::$dizin: iOS derlenemedi (ayrıntı ios-raporu dalında: $dizin-ios.txt)."
    hata=1
  fi
done

exit "$hata"
