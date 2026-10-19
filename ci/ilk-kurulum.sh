#!/usr/bin/env bash
# İlk kurulum: her uygulamanın android/ ve ios/ klasörlerini `flutter create` ile üretir.
# Depoda zaten bulunan dosyalara (ikonlar, açılış renkleri) dokunmaz; yalnızca eksikleri ekler.
# Klasörler bir kez oluşup depoya yazıldıktan sonra bu betik hiçbir şey yapmaz.
set -euo pipefail

KOK="$(cd "$(dirname "$0")/.." && pwd)"

kur() {
  local dizin="$1" ad="$2" etiket="$3" zemin_rgb="$4"
  local yol="$KOK/apps/$dizin"
  local manifest="$yol/android/app/src/main/AndroidManifest.xml"

  if [ -f "$manifest" ] && [ -f "$yol/ios/Runner.xcodeproj/project.pbxproj" ]; then
    echo "• $dizin: platform klasörleri hazır."
    return 0
  fi

  echo "• $dizin: flutter create çalışıyor…"
  (cd "$yol" && flutter create --org com.maisonmakas --project-name "$ad" --platforms android,ios .)

  # Ana ekranda görünen ad
  sed -i "s/android:label=\"[^\"]*\"/android:label=\"$etiket\"/" "$manifest"

  # İnternet izni (hesap, randevu ve bildirimler için gerekecek)
  if ! grep -q 'android.permission.INTERNET' "$manifest"; then
    sed -i '0,/<application/s//<uses-permission android:name="android.permission.INTERNET" \/>\n    <application/' "$manifest"
  fi

  # iOS görünen ad
  python3 - "$yol/ios/Runner/Info.plist" "$etiket" <<'PY'
import re, sys
yol, ad = sys.argv[1], sys.argv[2]
s = open(yol, encoding="utf-8").read()
s, n = re.subn(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)", lambda m: m.group(1) + ad + m.group(2), s)
if n == 0:
    s = s.replace("<dict>", "<dict>\n\t<key>CFBundleDisplayName</key>\n\t<string>" + ad + "</string>", 1)
open(yol, "w", encoding="utf-8").write(s)
PY

  # iOS açılış ekranı zemini (beyaz yerine marka rengi)
  local sb="$yol/ios/Runner/Base.lproj/LaunchScreen.storyboard"
  if [ -f "$sb" ]; then
    python3 - "$sb" "$zemin_rgb" <<'PY'
import re, sys
yol = sys.argv[1]
r, g, b = sys.argv[2].split()
s = open(yol, encoding="utf-8").read()
yeni = '<color key="backgroundColor" red="%s" green="%s" blue="%s" alpha="1" colorSpace="custom" customColorSpace="sRGB"/>' % (r, g, b)
s = re.sub(r'<color key="backgroundColor"[^>]*/>', lambda m: yeni, s)
open(yol, "w", encoding="utf-8").write(s)
PY
  fi

  echo "  ✓ $dizin hazır: $(grep -o 'android:label="[^"]*"' "$manifest")"
}

kur musteri musteri "Maison Makas" "0.0549 0.0549 0.0627"
kur pro pro "Makas Pro" "0.9686 0.9529 0.9255"
