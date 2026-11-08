# protoolbag_fixflow — Protoolbag FixFlow (mobil)

FixFlow saha / arıza yönetimi teknisyen uygulaması. Kendi kodu yok denecek kadar
incedir: tüm motorlar, shell (`MainShellScreen`, DB-menü), lisans
(`EntitlementService`), KVKK onay kapısı, onay gelen kutusu ve FixFlow teknisyen
modülü (`lib/src/core/fixflow/**`, `lib/src/presentation/fixflow/**`) paylaşılan
çekirdekten (`protoolbag_core`, `path: ../`) gelir.

| | |
|---|---|
| Aktif platform | `FIXFLOW` — `b1f1f10f-0000-4000-8000-000000000001` |
| Uygulama adı | Protoolbag FixFlow |
| Android applicationId | `com.protoolbag.protoolbag_fixflow` |
| iOS bundle id | `com.protoolbag.fixflow` |
| Universal link host | `app.fixflow.protoolbag.com` |
| OAuth dönüş şeması | `ptbfixflow://oauth-callback` |

## Kurulum

Repo kökünde değil, bu klasörde çalışın:

```bash
cd example_fixflow
flutter pub get
```

### Kullanıcının sağlaması gereken (gitignore'lu) dosyalar

Bu dosyalar repoya **girmez** (kök `.gitignore`: `.env`, `.env.local`,
`.env.*.local`). Değerleri kendiniz girin; asla commit etmeyin.

1. **`example_fixflow/.env`** — `pubspec.yaml` içinde asset olarak paketlenir.
   Yoksa uygulama "Yapılandırma eksik (.env)" ekranıyla açılır ve
   `flutter analyze` bir `asset_does_not_exist` uyarısı verir (diğer
   `example_*` uygulamalarıyla aynı davranış).

   ```dotenv
   SUPABASE_URL=            # zorunlu — Supabase proje URL'i
   SUPABASE_ANON_KEY=       # zorunlu — publishable/anon key
   API_BASE_URL=            # opsiyonel
   APP_NAME=Protoolbag FixFlow   # opsiyonel (varsayılan budur)
   DEBUG_MODE=false         # opsiyonel
   ```

2. **Android imzalama** — `android/key.properties` ve `*.jks` / `*.keystore`
   (`android/.gitignore`). Release yapılandırması şimdilik diğer uygulamalar
   gibi debug anahtarıyla imzalar (`build.gradle.kts` TODO).

3. **`android/local.properties`** — Flutter araçları üretir (`flutter.sdk`).

Firebase **kullanılmaz** (diğer uygulamalar gibi): `google-services.json` /
`GoogleService-Info.plist` gerekmez. iOS push, `AppDelegate.swift` içindeki
doğrudan APNs köprüsüyle (`ptb/apns` kanalı) çalışır; sunucu tarafı
`send-push` EF'i APNs anahtarını Supabase secret'larından okur ve
`apns-topic` olarak cihazın kaydettiği bundle id'yi (`com.protoolbag.fixflow`)
kullanır.

### Apple / Google tarafı (repo dışı)

- Apple Developer'da `com.protoolbag.fixflow` App ID: Push Notifications +
  Associated Domains yetenekleri (`Runner.entitlements`:
  `aps-environment`, `applinks:app.fixflow.protoolbag.com`).
- Universal / App Links için `https://app.fixflow.protoolbag.com/.well-known/`
  altında `apple-app-site-association` ve `assetlinks.json` barındırılmalı
  (uygulamada gönderilmez; yoksa link tarayıcıda açılır, uygulama yine çalışır).

## Mimari notlar

- `lib/main.dart` başlatma sırası (CRM/PPM ile aynı): `.env` → `CoreInitializer`
  → `PlatformContext.setActivePlatform(FIXFLOW, code: 'FIXFLOW')` →
  `registerFixflowAppScreens()` → `AppVersionGate` → `BrandingService.load` →
  push tap köprüsü → `runApp` → (ilk frame) `DeepLinkService.init`.
- `lib/config/fixflow_app_screens.dart` — çekirdek `registerFixflowScreens()`
  + OneDrive/SharePoint dosya kartı. Çözülen menü yolları: `/fixflow`,
  `/fixflow/tickets`, `/fixflow/work-requests`, `/fixflow/maintenance`,
  `/fixflow/sla`, `/fixflow/approvals`, ve deep-link `/fixflow/tickets/<id>`.
- `lib/config/push_routing.dart` — push tap: `action_url` → `route` /
  `deep_link` / `screen` → (`entityType=ticket` + `entityId`) sırasıyla yol
  seçer; shell rotaları `go_router`, diğerleri `ScreenResolver` ile açılır.

## Kontroller

```bash
flutter analyze
touch .env && TZ=UTC flutter test; rm -f .env   # boş .env yalnız test süresince
```

`flutter build` / `flutter run` bu repoda ajan iş akışında çalıştırılmaz;
cihaz testi kullanıcıdadır.
