// Maison Makas · randevu-bildirimi (Supabase Edge Function)
//
// Uygulama, randevu alındıktan ya da iptal edildikten sonra bu fonksiyonu { "randevu": "<id>" } ile çağırır.
// Fonksiyon kime ne gideceğini veritabanına sorar (randevu_bildirimi_hazirla — çağıranın yetkisiyle)
// ve bildirimi Firebase Cloud Messaging ile gönderir. Uygulama kapalı olsa da telefon bildirimi gösterir.
//
// Gereken sır (Edge Functions → Secrets): FIREBASE_SERVICE_ACCOUNT = Firebase'den indirilen
// hizmet hesabı .json dosyasının tamamı. Bu sır yalnız Supabase'te durur; koda ve depoya yazılmaz.
// "Verify JWT" kapalı olabilir: yetki denetimini veritabanı fonksiyonu yapar.

import { createClient } from 'npm:@supabase/supabase-js@2';

type Dil = 'tr' | 'en';
type Olay = 'yeni' | 'musteri_iptal' | 'salon_iptal';

interface Hazirlik {
  olay: Olay;
  randevu: string;
  salon: string;
  baslangic: string; // "2026-10-24 14:30" (salonun yerel saati)
  musteri: string;
  usta: string;
  hizmetler: string;
  alicilar: { jeton: string; dil: Dil }[];
}

interface HizmetHesabi {
  project_id: string;
  client_email: string;
  private_key: string;
}

const AYLAR: Record<Dil, string[]> = {
  tr: ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'],
  en: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November',
    'December'],
};
// JavaScript'te 0 = Pazar.
const GUNLER: Record<Dil, string[]> = {
  tr: ['Pazar', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi'],
  en: ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
};

function zaman(baslangic: string, dil: Dil): string {
  const m = /^(\d{4})-(\d{2})-(\d{2}) (\d{2}:\d{2})$/.exec(baslangic);
  if (!m) return baslangic;
  const [, y, a, g, saat] = m;
  const gun = new Date(Date.UTC(Number(y), Number(a) - 1, Number(g))).getUTCDay();
  return `${GUNLER[dil][gun]} ${Number(g)} ${AYLAR[dil][Number(a) - 1]} · ${saat}`;
}

function ekle(...parcalar: string[]): string {
  return parcalar.filter((p) => p.trim().length > 0).join(' · ');
}

function metin(h: Hazirlik, dil: Dil): { baslik: string; govde: string } {
  const z = zaman(h.baslangic, dil);
  const en = dil === 'en';
  switch (h.olay) {
    case 'yeni':
      return {
        baslik: en ? 'New booking' : 'Yeni randevu',
        govde: ekle(z, h.musteri, h.hizmetler, h.usta),
      };
    case 'musteri_iptal':
      return {
        baslik: en ? 'Booking cancelled' : 'Randevu iptal edildi',
        govde: ekle(z, h.musteri, en ? 'cancelled by the customer' : 'müşteri iptal etti'),
      };
    case 'salon_iptal':
      return {
        baslik: en ? 'Your booking was cancelled' : 'Randevun iptal edildi',
        govde: ekle(h.salon, z, en ? 'See My bookings for details.' : "Ayrıntı için Randevularım'a bak."),
      };
  }
}

// ------------------------------------------------------------ Google erişim anahtarı (OAuth 2, JWT ile)

let erisim: { anahtar: string; bitis: number } | null = null;

function base64url(veri: Uint8Array | string): string {
  const baytlar = typeof veri === 'string' ? new TextEncoder().encode(veri) : veri;
  let ikili = '';
  for (const b of baytlar) ikili += String.fromCharCode(b);
  return btoa(ikili).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function erisimAnahtari(hesap: HizmetHesabi): Promise<string> {
  const simdi = Math.floor(Date.now() / 1000);
  if (erisim && erisim.bitis - 60 > simdi) return erisim.anahtar;

  const pem = hesap.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '');
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const anahtar = await crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const baslik = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const icerik = base64url(JSON.stringify({
    iss: hesap.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: simdi,
    exp: simdi + 3600,
  }));
  const imza = new Uint8Array(
    await crypto.subtle.sign('RSASSA-PKCS1-v1_5', anahtar, new TextEncoder().encode(`${baslik}.${icerik}`)),
  );
  const yanit = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${baslik}.${icerik}.${base64url(imza)}`,
    }),
  });
  if (!yanit.ok) throw new Error(`Google erişim anahtarı alınamadı (${yanit.status}): ${await yanit.text()}`);
  const veri = await yanit.json() as { access_token: string; expires_in: number };
  erisim = { anahtar: veri.access_token, bitis: simdi + veri.expires_in };
  return veri.access_token;
}

// ------------------------------------------------------------ İstek

function yanitla(veri: unknown, durum = 200): Response {
  return new Response(JSON.stringify(veri), { status: durum, headers: { 'Content-Type': 'application/json' } });
}

Deno.serve(async (istek) => {
  if (istek.method !== 'POST') return yanitla({ hata: 'Yalnız POST' }, 405);

  const yetki = istek.headers.get('Authorization');
  const apikey = istek.headers.get('apikey') ?? Deno.env.get('SUPABASE_ANON_KEY');
  if (!yetki || !apikey) return yanitla({ hata: 'Giriş gerekli' }, 401);

  let randevu: unknown;
  try {
    randevu = (await istek.json())?.randevu;
  } catch {
    return yanitla({ hata: 'Geçersiz istek' }, 400);
  }
  if (typeof randevu !== 'string' || !/^[0-9a-f-]{36}$/i.test(randevu)) {
    return yanitla({ hata: 'Randevu kimliği eksik' }, 400);
  }

  // Sır yoksa olay "gönderildi" işaretlenmesin diye önce bakılır.
  const hesapMetni = Deno.env.get('FIREBASE_SERVICE_ACCOUNT');
  if (!hesapMetni) return yanitla({ hata: 'FIREBASE_SERVICE_ACCOUNT sırrı eklenmemiş' }, 500);
  let hesap: HizmetHesabi;
  try {
    hesap = JSON.parse(hesapMetni);
  } catch {
    return yanitla({ hata: 'FIREBASE_SERVICE_ACCOUNT geçerli bir JSON değil' }, 500);
  }

  const supabase = createClient(Deno.env.get('SUPABASE_URL')!, apikey, {
    global: { headers: { Authorization: yetki } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await supabase.rpc('randevu_bildirimi_hazirla', { p_randevu: randevu });
  if (error) return yanitla({ hata: error.message }, 400);
  const h = data as Hazirlik | null;
  if (!h || h.alicilar.length === 0) return yanitla({ gonderilen: 0, toplam: 0 });

  const anahtar = await erisimAnahtari(hesap);
  const sonuclar = await Promise.all(h.alicilar.map(async (a) => {
    const { baslik, govde } = metin(h, a.dil === 'en' ? 'en' : 'tr');
    const yanit = await fetch(`https://fcm.googleapis.com/v1/projects/${hesap.project_id}/messages:send`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${anahtar}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: {
          token: a.jeton,
          notification: { title: baslik, body: govde },
          android: {
            priority: 'HIGH',
            notification: { channel_id: 'randevu', tag: `${h.randevu}-${h.olay}` },
          },
          apns: { payload: { aps: { sound: 'default' } } },
          data: { randevu: h.randevu, olay: h.olay },
        },
      }),
    });
    if (!yanit.ok) console.error('FCM', yanit.status, await yanit.text());
    return yanit.ok;
  }));
  return yanitla({ gonderilen: sonuclar.filter(Boolean).length, toplam: sonuclar.length });
});
