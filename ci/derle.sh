#!/usr/bin/env bash
# Maison Makas — GitHub Actions derleme betiği.
# İş akışı (.github/workflows/android.yml) Flutter'ı kurduktan sonra bunu çalıştırır.
set -euo pipefail

cd "$(dirname "$0")/.."
NO="${GITHUB_RUN_NUMBER:-1}"
DAL="${GITHUB_REF_NAME:-main}"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

echo "::group::Flutter sürümü"
flutter --version
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

# 2) Sabit imza anahtarı: her APK aynı anahtarla imzalanır,
#    böylece yeni sürüm eskisinin üstüne kaldırmadan kurulur.
for d in "${ANDROID_USER_HOME:-}" "$HOME/.android"; do
  [ -n "$d" ] || continue
  mkdir -p "$d"
  cp ci/debug.keystore "$d/debug.keystore"
done

# 3) Analiz, test ve APK
mkdir -p cikti
derle() {
  local dizin="$1" dosya="$2"
  echo "::group::$dizin — analiz ve test"
  (
    cd "apps/$dizin"
    flutter pub get
    flutter analyze --no-fatal-infos --no-fatal-warnings || echo "::warning::$dizin: analizde hata bulundu (yukarıdaki satırlara bakın)."
    flutter test || echo "::warning::$dizin: testler geçmedi (yukarıdaki satırlara bakın)."
  )
  echo "::endgroup::"
  echo "::group::$dizin — APK"
  (
    cd "apps/$dizin"
    flutter build apk --release --build-number="$NO"
  )
  cp "apps/$dizin/build/app/outputs/flutter-apk/app-release.apk" "cikti/$dosya-$NO.apk"
  echo "::endgroup::"
}
derle musteri maison-makas
derle pro makas-pro

# 4) Bilgi: imza parmak izi (her derlemede aynı olmalı)
ARAC="$(ls -d "${ANDROID_HOME:-/usr/local/lib/android/sdk}"/build-tools/*/ 2>/dev/null | sort -V | tail -1 || true)"
if [ -n "$ARAC" ] && [ -x "${ARAC}apksigner" ]; then
  for apk in cikti/*.apk; do
    echo "$apk → $("${ARAC}apksigner" verify --print-certs "$apk" | grep -m1 'SHA-256' || true)"
  done
fi
ls -la cikti
