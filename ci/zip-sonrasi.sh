#!/usr/bin/env bash
# Zip açıldıktan hemen sonra iş akışı bunu çalıştırır.
# ci/silinecekler.txt varsa içindeki yolları (her satıra bir tane) depodan siler.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f ci/silinecekler.txt ]; then
  while IFS= read -r yol || [ -n "$yol" ]; do
    yol="${yol%%#*}"
    yol="$(echo "$yol" | xargs)"
    [ -n "$yol" ] || continue
    case "$yol" in
      /*|*..*) echo "Atlandı (güvensiz yol): $yol"; continue ;;
    esac
    if [ -e "$yol" ]; then
      git rm -r -q --ignore-unmatch -- "$yol" || true
      rm -rf -- "$yol"
      echo "Silindi: $yol"
    fi
  done < ci/silinecekler.txt
  rm -f ci/silinecekler.txt
fi
