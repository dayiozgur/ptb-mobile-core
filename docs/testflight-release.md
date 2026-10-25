# TestFlight Yayın Rehberi

4 ürün uygulaması TestFlight'a hazır: **CRM, PHR, PMS, PPM** (paid team `283AHKB4WM`).
`example/` demo'su yayınlanmaz.

| App | Bundle ID | Display Name | Assoc. Domains |
|-----|-----------|--------------|----------------|
| CRM | `com.protoolbag.crm` | Protoolbag CRM | `applinks:app.crm.protoolbag.com` |
| PHR | `com.protoolbag.phr` | Protoolbag HR | — |
| PMS | `com.protoolbag.pms` | Protoolbag Pms | — |
| PPM | `com.protoolbag.ppm` | Protoolbag PM | — |

Sürüm: hepsi `1.0.0 (build 1)` — pubspec'ten (`FLUTTER_BUILD_NAME/NUMBER`).

## Kod/config tarafı — HAZIR (bu commit)

- ✅ `ITSAppUsesNonExemptEncryption=false` (4 Info.plist) → export-compliance sorusu otomatik yanıtlı, upload bloklanmaz. *(Uygulama yalnızca standart HTTPS/TLS + platform kripto (Keychain/TOTP) kullanıyor; özel kripto yoksa doğru. Değişirse gözden geçir.)*
- ✅ `aps-environment=production` (4 entitlements) → TestFlight/App Store production APNs. *(Not: Xcode'dan doğrudan debug push'u artık production APNs'e gider.)*
- ✅ `ios/ExportOptions.plist` (4 app) → `app-store-connect`, team `283AHKB4WM`, automatic signing.
- ✅ `scripts/build-testflight.sh` → `flutter build ipa` + `xcrun altool` validate+upload.

## Apple tarafı — SENİN yapman gerekenler (login gerektirir)

1. **App Store Connect'te uygulama kaydı** (her bundle id için): App Store Connect → Apps → **+** → New App → platform iOS, bundle id'yi seç, isim + SKU gir. 4 app için tekrarla.
2. **Xcode'a giriş:** Xcode → Settings → Accounts → team `283AHKB4WM` hesabınla giriş yap (automatic signing distribution cert + profili indirir).
3. **Capabilities** (App ID başına, Developer portal → Identifiers): **Push Notifications** ve **Associated Domains** (yalnız CRM) etkin olmalı.
   - Push için: bir **APNs Auth Key** (.p8) oluştur (Keys → **+** → Apple Push Notifications service). Bu, cihaz push'unun çalışması için gerekli (upload için değil).
   - CRM associated-domains için: `https://app.crm.protoolbag.com/.well-known/apple-app-site-association` (AASA) dosyası host'ta yayında olmalı (deep-link doğrulaması — STORY-0083). *Bu senin/DNS tarafın.*
4. **App Store Connect API issuer id'yi bul:** App Store Connect → Users and Access → **Integrations** → App Store Connect API → **Issuer ID**'yi kopyala. (API key `9M78BB6JK8` zaten `.secrets/AuthKey_9M78BB6JK8.p8` olarak repo'da, git'e dahil değil.)

## Yükleme (senin makinende, giriş sonrası)

```bash
# İlk yükleme (build 1 zaten config'de):
./scripts/build-testflight.sh crm <ISSUER_ID>

# 4 app için tekrarla:
./scripts/build-testflight.sh phr <ISSUER_ID>
./scripts/build-testflight.sh pms <ISSUER_ID>
./scripts/build-testflight.sh ppm <ISSUER_ID>
```

Aynı sürümün ikinci yüklemesinde build numarasını artır:

```bash
./scripts/build-testflight.sh crm <ISSUER_ID> 2
```

Yükleme sonrası App Store Connect → TestFlight'ta işlenmesi ~5–15 dk. İç test grubuna tester ekleyip davet gönderebilirsin (export-compliance sorusu otomatik yanıtlı).

## Kalan opsiyonel iyileştirmeler

- `example_pms` display adı "Protoolbag Pms" → "Protoolbag PMS" (kozmetik).
- fastlane (`pilot`) ile daha zengin metadata/otomasyon (şu an altool yeterli).
- Push'un uçtan uca doğrulanması: APNs key + App ID capability + cihaz token → `push_notification_service.dart`.

## Release build hardening (CRA A-08)

Tüm mağaza/TestFlight build'leri **obfuscated** ve Dart sembolleri ayrılmış olarak üretilir:

| Platform | Komut | Semboller |
|---|---|---|
| iOS | `./scripts/build-testflight.sh <app> <ISSUER_ID> [build]` (`flutter build ipa --release --obfuscate --split-debug-info=…`) | `example_<app>/build/debug-info/ios/<version>[-b<build>]/` |
| Android | `./scripts/build-release-android.sh <app> [build]` (`flutter build appbundle --release --obfuscate --split-debug-info=…`) | `example_<app>/build/debug-info/android/<version>[-b<build>]/` |

- Sembol klasörünü **her sürümle birlikte arşivle** (git'e girmez; `build/` ignore). Crash stack-trace çözümü:
  `flutter symbolize -i <trace.txt> -d <symbols-dir>/app.<arch>.symbols`.
- Elle build alınacaksa da bayraklar zorunlu: `--release --obfuscate --split-debug-info=<dir>`.
- Ağ: Android `network_security_config` cleartext'i kapatır (debug override yalnız localhost/10.0.2.2); iOS ATS
  `NSAllowsArbitraryLoads=false`.
- Minimum sürüm: `AppVersionGate` `platform_app_configs.min_mobile_app_version` değerini okur (kolon eklenince aktif;
  bkz. `lib/src/core/config/app_version_gate.dart`).
- Android release imzası henüz debug anahtarıyla (Gradle şablonu) — mağaza yüklemesi öncesi gerçek upload key
  (`key.properties`, git-ignored) yapılandırılmalı.
