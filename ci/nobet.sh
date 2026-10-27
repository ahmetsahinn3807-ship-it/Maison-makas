#!/usr/bin/env bash
# Sunucu nöbeti: Supabase ücretsiz planda 7 gün kullanılmayan projeyi durdurur.
# İş akışı (.github/workflows/play.yml) bunu her gün bir kez çalıştırır; uygulamanın da kullandığı
# herkese açık (publishable) anahtarla salon listesinden tek satır okur. Gizli bilgi kullanmaz.
set -euo pipefail
cd "$(dirname "$0")/.."
AYAR=packages/makas_core/lib/src/supabase_ayar.dart
URL="$(sed -n "s/.*url = '\([^']*\)'.*/\1/p" "$AYAR" | head -1)"
ANAHTAR="$(sed -n "s/.*publishableKey = '\([^']*\)'.*/\1/p" "$AYAR" | head -1)"
kod="$(curl -sS -o /dev/null -w '%{http_code}' --retry 3 --max-time 30 \
  -H "apikey: $ANAHTAR" "$URL/rest/v1/salonlar?select=id&limit=1" || echo 000)"
echo "Supabase yanıtı: HTTP $kod"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "Sunucu nöbeti: Supabase HTTP $kod ($(date -u +%Y-%m-%dT%H:%MZ))" >> "$GITHUB_STEP_SUMMARY"
fi
if [ "$kod" != "200" ]; then
  echo "::error::Supabase yanıt vermedi (HTTP $kod). Proje durdurulmuş olabilir: Supabase panelinde Resume project."
  exit 1
fi
