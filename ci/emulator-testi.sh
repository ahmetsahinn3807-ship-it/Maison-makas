#!/usr/bin/env bash
# Emülatör duman testi (derle.sh çağırır).
#
# Derlenen iki APK'yı bir Android emülatörüne kurar, açar, giriş ekranına geçer ve
# yanlış bir şifreyle giriş dener. "E-posta ya da şifre hatalı" yanıtı gelirse uygulama
# sunucuya ulaşabiliyor demektir. Hesap oluşturmaz, veritabanına yazmaz.
#
# Sonuçlar rapor klasörüne yazılır: ekran görüntüleri, logcat, ekran ağaçları, kısa özet.
# Hiçbir adım derlemeyi durdurmaz; her adımın süre sınırı vardır.
set -uo pipefail
cd "$(dirname "$0")/.."

RAPOR="${1:-cikti-rapor}"
mkdir -p "$RAPOR"
SDK="${ANDROID_HOME:-/usr/local/lib/android/sdk}"
ADB="$SDK/platform-tools/adb"
GORUNTU="system-images;android-34;google_apis;x86_64"
OZET="$RAPOR/07-duman-ozet.txt"
GUNLUK="$RAPOR/08-emulator-gunluk.txt"
: > "$OZET"

yaz() { echo "[emülatör] $*" | tee -a "$GUNLUK"; }
sonuc() { echo "$*" >> "$OZET"; yaz "SONUÇ: $*"; }

ARAC_DIZINI=""
for d in "$SDK/cmdline-tools/latest/bin" "$SDK"/cmdline-tools/*/bin; do
  if [ -x "$d/sdkmanager" ]; then ARAC_DIZINI="$d"; break; fi
done
if [ -z "$ARAC_DIZINI" ]; then
  sonuc "Emülatör kurulamadı: sdkmanager bulunamadı."
  exit 0
fi

yaz "KVM izni veriliyor"
echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' \
  | sudo tee /etc/udev/rules.d/99-kvm4all.rules >/dev/null
sudo udevadm control --reload-rules
sudo udevadm trigger --name-match=kvm
ls -la /dev/kvm >> "$GUNLUK" 2>&1

yaz "Emülatör ve sistem görüntüsü indiriliyor"
yes 2>/dev/null | timeout 180 "$ARAC_DIZINI/sdkmanager" --licenses >/dev/null 2>&1
if ! timeout 900 "$ARAC_DIZINI/sdkmanager" --install "emulator" "$GORUNTU" >> "$GUNLUK" 2>&1; then
  sonuc "Emülatör kurulamadı: sistem görüntüsü indirilemedi."
  exit 0
fi
EMU="$SDK/emulator/emulator"

if ! echo no | "$ARAC_DIZINI/avdmanager" create avd -n maison -k "$GORUNTU" -d pixel_6 --force >> "$GUNLUK" 2>&1; then
  echo no | "$ARAC_DIZINI/avdmanager" create avd -n maison -k "$GORUNTU" --force >> "$GUNLUK" 2>&1 || {
    sonuc "Emülatör kurulamadı: sanal cihaz oluşturulamadı."
    exit 0
  }
fi

yaz "Emülatör açılıyor"
"$EMU" -avd maison -no-window -no-audio -no-boot-anim -no-snapshot -gpu swiftshader_indirect \
  >> "$RAPOR/09-emulator-cikti.txt" 2>&1 &
EMU_PID=$!
kapat() {
  timeout 20 "$ADB" emu kill >/dev/null 2>&1
  sleep 3
  kill "$EMU_PID" >/dev/null 2>&1
}
trap kapat EXIT

if ! timeout 300 "$ADB" wait-for-device; then
  sonuc "Emülatör açılmadı (cihaz görünmedi)."
  exit 0
fi
acildi=0
for _ in $(seq 1 150); do
  if [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; then
    acildi=1
    break
  fi
  sleep 2
done
if [ "$acildi" != 1 ]; then
  sonuc "Emülatör açılışı tamamlanmadı."
  exit 0
fi
yaz "Emülatör hazır"
for ayar in window_animation_scale transition_animation_scale animator_duration_scale; do
  "$ADB" shell settings put global "$ayar" 0 >/dev/null 2>&1
done
sleep 5

# Ekran ağacını alır; verilen metinlerden birini içeren ilk öğenin ortasına dokunur.
dokun() {
  local dosya="$1"
  shift
  "$ADB" shell uiautomator dump /sdcard/agac.xml >/dev/null 2>&1
  "$ADB" shell cat /sdcard/agac.xml > "$dosya" 2>/dev/null
  local nokta
  nokta="$(python3 - "$dosya" "$@" <<'PY'
import re, sys
yol, aranan = sys.argv[1], sys.argv[2:]
try:
    s = open(yol, encoding="utf-8", errors="ignore").read()
except OSError:
    sys.exit(0)
for m in re.finditer(r"<node [^>]*>", s):
    n = m.group(0)
    deger = " ".join(re.findall(r' (?:text|content-desc)="([^"]*)"', n))
    if any(a in deger for a in aranan):
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', n)
        if b:
            x1, y1, x2, y2 = map(int, b.groups())
            print((x1 + x2) // 2, (y1 + y2) // 2)
            break
PY
)"
  if [ -z "$nokta" ]; then
    return 1
  fi
  # shellcheck disable=SC2086
  "$ADB" shell input tap $nokta
}

# Ekrandaki n'inci yazı alanına (EditText) dokunur.
alana_dokun() {
  local dosya="$1" sira="$2"
  "$ADB" shell uiautomator dump /sdcard/agac.xml >/dev/null 2>&1
  "$ADB" shell cat /sdcard/agac.xml > "$dosya" 2>/dev/null
  local nokta
  nokta="$(python3 - "$dosya" "$sira" <<'PY'
import re, sys
yol, sira = sys.argv[1], int(sys.argv[2])
try:
    s = open(yol, encoding="utf-8", errors="ignore").read()
except OSError:
    sys.exit(0)
alanlar = [n for n in re.findall(r"<node [^>]*>", s) if 'class="android.widget.EditText"' in n]
if len(alanlar) > sira:
    b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', alanlar[sira])
    if b:
        x1, y1, x2, y2 = map(int, b.groups())
        print((x1 + x2) // 2, (y1 + y2) // 2)
PY
)"
  if [ -z "$nokta" ]; then
    return 1
  fi
  # shellcheck disable=SC2086
  "$ADB" shell input tap $nokta
}

ekran() { "$ADB" exec-out screencap -p > "$RAPOR/$1.png" 2>/dev/null; }

dene() {
  local ad="$1" paket="$2"
  shift 2
  local apk
  apk="$(ls cikti/"$ad"-*.apk 2>/dev/null | head -1)"
  if [ -z "$apk" ]; then
    sonuc "$ad: APK bulunamadı."
    return
  fi
  yaz "$paket kuruluyor ($apk)"
  if ! timeout 240 "$ADB" install -r -g "$apk" >> "$GUNLUK" 2>&1; then
    sonuc "$ad: APK emülatöre kurulamadı."
    return
  fi
  "$ADB" logcat -c >/dev/null 2>&1
  "$ADB" shell monkey -p "$paket" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1
  sleep 15
  ekran "$ad-1-acilis"
  if ! dokun "$RAPOR/$ad-agac-1.xml" "$@"; then
    sleep 8
    dokun "$RAPOR/$ad-agac-1.xml" "$@" || {
      ekran "$ad-2-giris"
      "$ADB" logcat -d -v time > "$RAPOR/$ad-logcat.txt" 2>/dev/null
      sonuc "$ad: açılış ekranında giriş düğmesi bulunamadı (ekran görüntüsüne bakılmalı)."
      return
    }
  fi
  sleep 4
  alana_dokun "$RAPOR/$ad-agac-2.xml" 0 && "$ADB" shell input text "ci.duman@example.com"
  sleep 1
  alana_dokun "$RAPOR/$ad-agac-3.xml" 1 && "$ADB" shell input text "Yanlis-sifre-123"
  sleep 1
  "$ADB" shell input keyevent 66
  sleep 10
  "$ADB" shell uiautomator dump /sdcard/agac.xml >/dev/null 2>&1
  "$ADB" shell cat /sdcard/agac.xml > "$RAPOR/$ad-agac-4.xml" 2>/dev/null
  ekran "$ad-2-giris"
  "$ADB" logcat -d -v time > "$RAPOR/$ad-logcat.txt" 2>/dev/null
  grep -E "MAISON|flutter|GeneratedPlugin|AndroidRuntime|FATAL" "$RAPOR/$ad-logcat.txt" \
    > "$RAPOR/$ad-logcat-ozet.txt" 2>/dev/null
  local metin
  metin="$(grep -o -E '(text|content-desc)="[^"]+"' "$RAPOR/$ad-agac-4.xml" 2>/dev/null | sed -E 's/^[a-z-]+="//; s/"$//' | tr '\n' ' ')"
  if echo "$metin" | grep -q "hatalı"; then
    sonuc "$ad: sunucuya ulaştı ✓ (yanlış şifreye 'hatalı' yanıtı geldi)"
  elif echo "$metin" | grep -q "Sunucu bağlantısı kurulamadı"; then
    sonuc "$ad: BAŞLATMA HATASI — $(echo "$metin" | grep -o 'Sunucu bağlantısı kurulamadı[^|]*' | head -c 400)"
  elif echo "$metin" | grep -q -i "internet"; then
    sonuc "$ad: ağ hatası — $(echo "$metin" | head -c 300)"
  else
    sonuc "$ad: sonuç belirsiz — ekranda: $(echo "$metin" | head -c 300)"
  fi
}

dene maison-makas com.maisonmakas.musteri "Hesabım var" "I have an account" "Ich habe ein Konto"
dene makas-pro com.maisonmakas.pro "Giriş yap"
yaz "Bitti"
