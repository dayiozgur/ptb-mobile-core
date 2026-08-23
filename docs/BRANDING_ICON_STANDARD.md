# Protoolbag Uygulama İkonu Standardı

Bu belge, Protoolbag mobil uygulama ikonlarının (iOS AppIcon) **tek tasarım
standardını** tanımlar. Yeni bir platform-app eklendiğinde veya ikon
güncellendiğinde bu standart birebir uygulanır.

## Referans (altın örnek)

**PPM (Protoolbag Project Management)** ikonu standardın referansıdır:
`example_ppm/ios/Runner/Assets.xcassets/AppIcon.appiconset/`

Doğru bir Protoolbag ikonu şu iki katmandan oluşur:

1. **Arka plan — radyal gradyan.** Marka renginin merkezde AÇIK, kenarlara doğru
   KOYU tonu. Merkez, logonun biraz üstünde (~%42 yükseklik) konumlanır. Yumuşak
   geçiş (ease ~1.15). Düz/flat renk KULLANILMAZ — daima gradyan.

2. **Logo — 3D katmanlı beyaz protoolbag markası.** Beyaz DEĞİL, **beyaz-gri
   gölgeli**: üst yüz parlak beyaz, yan/iç yüzler gri tonlanmış (kağıt-katlama
   3D derinliği). Bu gölge/derinlik markanın kimliğidir.

## KRİTİK KURAL — logonun 3D derinliği korunmalı

⛔ **Logoyu düz-beyaz (tek ton) YAPMA.** Geçmişte bir üretim, logoyu luminance
eşiğiyle düz beyaza çevirdi → 3D gölge kayboldu → ikon "bozuk" göründü.

✅ **Doğru yöntem:** Logoyu **GRİ-TON (luminance, R=G=B)** olarak taşı; yalnız
ARKA PLANI yeni marka-gradyanıyla değiştir. Böylece 3D gölge (luminance farkı)
korunur ve renk-kirliliği olmaz.

⛔ **İKİNCİ TUZAK — kenar renk-halosu.** Raster kaynak ikonun (ör. CRM) logo
KENARLARI, kaynağın kendi arka-plan rengiyle (CRM mavisi) anti-alias'lıdır.
Logonun RENGİNİ olduğu gibi taşırsan, bu mavi-kenar farklı-renk bg'ye (mor/mavi
PMS) taşınınca **kenar renk-halosu/kirlilik** yapar (CRM'de sorun görünmez çünkü
zaten mavi). ÇÖZÜM: logoyu **gri-tona çevir** (yukarıdaki doğru yöntem) —
renksiz gri kenar, yeni bg ile temiz karışır. Test: üretileni 180px'e (60@3x,
telefon boyutu) küçültüp CRM referansıyla yan yana karşılaştır; kenar temiz +
3D gölge var olmalı.

⛔ **ÜÇÜNCÜ TUZAK — gölge renk-ailesi uyumu.** Logonun 3D gölge yüzleri
(sol/iç yüzler), kaynak ikonun ARKA-PLAN rengine göre tonlanmıştır. CRM
logosunun gölge-yüzleri MAVİ-tonlu gridir. Bunu MOR (PHR) bg'ye taşırsan
gri-yüzler mavi görünüp mor'la çelişir → "gri bölümler bozuk". ÇÖZÜM:
**kaynak-logo, hedef bg'nin renk-ailesiyle eşleşmeli.** PHR (mor) → PHR'nin
kendi mor-tonlu logosu. PMS/CRM (mavi) → CRM logosu (mavi-mavi uyumlu). Yeni
bir platform farklı renk-ailesindeyse, o platform için gölge-uyumlu bir kaynak
logo gerekir (kendi orijinali veya nötr-gri desatüre — ama desatüre logoyu
matlaştırır, tercih kendi-renkli kaynak).

## Marka renkleri (radyal gradyan: merkez → kenar)

| App | Platform rengi | Merkez (açık) | Kenar (koyu) |
|-----|----------------|---------------|--------------|
| CRM | Mavi `#2563EB`  | `#3B82F6` | `#1E3A8A` |
| PPM | Teal `#0D9488`  | `#14B8A6` | `#0F766E` |
| PHR | Mor `#7C3AED`   | `#8B5CF6` | `#4C1D95` |
| PMS | Mavi `#1C6AE9`  | `#2F7BF0` | `#11408F` |

(Renkler `environment.dart` `Environment.brandColor` + DB `platform_app_configs.
primary_color` ile tutarlıdır.)

## Üretilecek iOS boyutları (15 dosya)

`AppIcon.appiconset/` içinde: 20/29/40/60/76/83.5 pt × @1x/@2x/@3x + 1024×1024.
Tam liste `Contents.json`'dadır. Master 1024×1024 üretilip diğerleri ondan
`average` interpolasyonla küçültülür.

## Üretim yordamı (özet)

1. Referans ikon seç (logo kaynağı): CRM veya PPM'in orijinal 1024 PNG'si
   (3D beyaz-gri logo + gradyan). Gerekirse git'ten çıkar:
   `git show <commit>:example_crm/.../Icon-App-1024x1024@1x.png > /tmp/logo.png`
2. Her piksel için:
   - `lum` = referans pikselin parlaklığı. `a = clamp((lum-0.5)/0.28, 0, 1)`
     → logo alfa (parlak=logo, koyu=bg). Yumuşak kenar.
   - `grad` = radyal gradyan (merkez `cx=512, cy=430`, ease 1.15).
   - Çıktı = `lerp(grad, referansPixel, a)` → **logo bölgesinde orijinal
     beyaz-gri (3D korunur), bg'de yeni gradyan.**
3. 15 boyuta resize + `AppIcon.appiconset/`'e yaz.
4. Üretim için `image` paketi geçici `dev_dependencies`'e eklenir, iş bitince
   KALDIRILIR (runtime bağımlılığı değil).

## Doğrulama

- Üretilen 1024'ü görsel incele: logo **3D gölgeli** mi (PPM ile aynı derinlik),
  arka plan **gradyan** mı? Düz-beyaz logo veya flat-bg = RED.
- Boyutlar `Contents.json` ile eşleşmeli (`sips -g pixelWidth`).
- Cihaza `flutter build ios --profile && flutter install` ile kur; ana ekranda
  4 app aynı marka-dilinde (derinlikli logo + renk-gradyan) görünmeli.

## Deploy notu

İkon değişikliği build gerektirir. Bir app'in ikonunu değiştirdiysen O APP'İ
redeploy et — dosyayı düzeltmek yetmez, cihazdaki eski build ikonu taşır.
