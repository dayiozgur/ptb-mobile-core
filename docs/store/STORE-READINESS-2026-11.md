# Store readiness — six mobile apps (2026-11-13)

Scope: `example_pms`, `example_crm`, `example_phr`, `example_ppm`, `example_fixflow`, `example_pem`
on branch `lane/store-prep`. Everything here was read from the repository and from the live
database (SELECT only). **Nothing was built, signed, uploaded or submitted in this lane**; whatever
needs a build or a device is marked **to verify**. Store rules are quoted only where they are
certain; the rest is marked **to verify** and must be checked in the consoles on the day of
submission.

Related files

- Listing texts (tr / en): [`listings/`](listings/)
- Deep-link association files (templates with placeholders): [`well-known/`](well-known/)
- New UI keywords (not applied): [`../proposed-sql/20261113_mobile_store_prep_keywords.sql`](../proposed-sql/20261113_mobile_store_prep_keywords.sql)
- TestFlight upload procedure (existing): [`../testflight-release.md`](../testflight-release.md)

---

## 1. Verdict

**None of the six apps can be submitted today.** Three blockers apply to all of them, and they are
not repository work:

| # | Blocker (all apps) | Why it blocks | Who |
|---|---|---|---|
| B1 | **No account-deletion path.** There is no "delete my account" in the apps and none in the web app either (the web has tenant erasure for operators and user removal for tenant admins only). | Apple 5.1.1(v) and Google Play's account-deletion policy require a way to delete the account for apps with accounts; Play also asks for a deletion **web URL** in the Data safety form. Accounts here are provisioned by the customer's administrator, but the app also completes sign-up (invite → set password) and has an access-request form, so neither store can be assumed to waive it. | Owner: product decision + a server-side request flow + an in-app entry and a public web page |
| B2 | **Android release signing uses the debug key** (`signingConfig = signingConfigs.getByName("debug")` in all six `build.gradle.kts`). | Play rejects debug-signed bundles. | Owner: upload keystore + `key.properties` (git-ignored) + Play App Signing |
| B3 | **No reviewer access.** Sign-in is invite-only; a reviewer cannot get in without credentials and a tenant with data. | Both stores reject apps they cannot sign in to. | Owner: demo tenant + accounts (see §9) |

App-specific blockers and open risks are in §2 and §10. What was fixed in the repository is in §11.

---

## 2. Readiness table

Legend: ✅ in place · 🔧 fixed in this lane (commit in §11) · ⚠️ gap, not a hard blocker · ⛔ blocker ·
❓ to verify (needs a build, a device or a console).

### 2.1 Identity and versions

| | PMS | CRM | PHR | PPM | FixFlow | PEM |
|---|---|---|---|---|---|---|
| iOS bundle id | `com.protoolbag.pms` | `com.protoolbag.crm` | `com.protoolbag.phr` | `com.protoolbag.ppm` | `com.protoolbag.fixflow` | `com.protoolbag.pem` |
| Android applicationId | `com.protoolbag.pms.protoolbag_pms` ⚠️ | `com.protoolbag.protoolbag_crm` ⚠️ | `com.protoolbag.example_phr` ⚠️ | `com.protoolbag.protoolbag_ppm` ⚠️ | `com.protoolbag.protoolbag_fixflow` ⚠️ | `com.protoolbag.protoolbag_pem` ⚠️ |
| Display name (both stores) | Protoolbag PMS 🔧 | Protoolbag CRM 🔧 (Android) | Protoolbag HR 🔧 (Android) | Protoolbag PM 🔧 (Android) | Protoolbag FixFlow ✅ | Protoolbag PEM ✅ |
| Version / build | `1.0.0+1` | `1.0.0+1` | `1.0.0+1` | `1.0.0+1` | `1.0.0+1` | `1.0.0+1` |
| iOS development team in project | `283AHKB4WM` | `283AHKB4WM` | `283AHKB4WM` | `283AHKB4WM` | `283AHKB4WM` | `5F37BRKPX9` ⚠️ different |
| `ios/ExportOptions.plist` | ✅ | ✅ | ✅ | ✅ | ✅ | ⛔ missing |
| `ios/Podfile.lock` committed | ✅ | ✅ | ✅ | ✅ | ⚠️ none | ⚠️ none |

- **Android application ids are the project template names** and differ from the iOS bundle ids
  (`example_phr` in particular). An applicationId is permanent once an app is published. Recommended
  before the first upload: `com.protoolbag.<code>` like iOS. Not changed here: it is an identity
  decision, and the Play listing, `assetlinks.json` and any future push configuration all hang on it.
- **Version scheme** (already implemented): the marketing version comes from each app's
  `pubspec.yaml` (`version: X.Y.Z+N` → iOS `CFBundleShortVersionString` / `CFBundleVersion`, Android
  `versionName` / `versionCode`). The build number must increase with every upload of the same
  version; both release scripts take it as an argument. Proposal: first submission `1.0.0`, build
  numbers counted per app from 1 (TestFlight) and never reused; a shared-core change that ships in
  all apps bumps the patch version of all six together.
- The Settings screen showed a hardcoded "1.0.0 (Build 1)"; it now shows the installed version 🔧.

### 2.2 SDK levels

| | PMS | CRM | PHR | PPM | FixFlow | PEM |
|---|---|---|---|---|---|---|
| Android minSdk / targetSdk / compileSdk | 24 / 36 / 36 | 24 / 36 / 36 | 24 / 36 / 36 | 24 / 36 / 36 | 24 / 36 / 36 | 24 / 36 / 36 |
| iOS deployment target (Xcode project) | 13.0 ❓ | 13.0 ❓ | 13.0 ❓ | 15.0 | 13.0 ❓ | 15.0 |
| Device families (iOS) | iPhone + iPad | iPhone + iPad | iPhone + iPad | iPhone + iPad | iPhone + iPad | iPhone + iPad |

- Android values are the toolchain defaults of the installed SDK (`flutter.minSdkVersion` = 24,
  `targetSdkVersion` = 36, `compileSdkVersion` = 36; Java 17). Google Play requires new apps and
  updates to target a recent API level (API 35 since 31 Aug 2025); 36 satisfies that. The exact level
  required on the submission date: **to verify** in Play Console.
- **iOS deployment target, to verify:** four projects say 13.0. The ML Kit pods in the committed
  `Podfile.lock` (GoogleMLKit 6.0.0, pulled in by the text-recognition and barcode plugins of the
  shared core) state a higher minimum iOS version than 13.0. The lock files exist, so `pod install`
  succeeded at some point, but no iOS build was run here. If the archive fails on the deployment
  target, raise it to the pods' minimum in the four projects (PPM and PEM already use 15.0).
- **16 KB memory pages (Android 15+), to verify:** Play requires it for apps targeting Android 15+.
  The toolchain's NDK (28.2) aligns the app's own libraries; the bundled ML Kit native libraries must
  be checked with the first AAB (Play Console flags it at upload).
- **iPad:** all six projects target iPhone and iPad and allow every iPad orientation. Apple will
  test on iPad and requires 13-inch iPad screenshots. Either run an iPad layout pass, or set the
  device family to iPhone only before the first submission (an owner decision; removing iPad
  support later is not allowed once published).
- Apple requires uploads to be built with a current Xcode / SDK; the machine has Xcode 26.6. The
  minimum accepted on the submission date: **to verify** in App Store Connect.

### 2.3 Icons and splash

| | PMS | CRM | PHR | PPM | FixFlow | PEM |
|---|---|---|---|---|---|---|
| iOS AppIcon set (16 files incl. 1024 px, no alpha) | ✅ | ✅ | ✅ | ✅ | ⚠️ identical to CRM | ✅ |
| Android launcher icons (5 densities) | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 ⚠️ CRM artwork | 🔧 |
| Android adaptive icon (foreground / background) | ⚠️ none | ⚠️ none | ⚠️ none | ⚠️ none | ⚠️ none | ⚠️ none |
| Play listing icon 512 px, feature graphic 1024×500 | ⛔ to produce | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ |
| Launch screen | blank (template) ⚠️ | blank ⚠️ | blank ⚠️ | blank ⚠️ | blank ⚠️ | blank ⚠️ |

- All six Android apps shipped the **toolchain's default launcher icon**. They now use each app's
  own iOS brand icon, downscaled (no redraw) 🔧.
- **FixFlow has no icon of its own**: its iOS AppIcon set is byte-identical to CRM's. Design item.
- Launch screens are the empty template (white, 1×1 image on iOS; `launch_background.xml` on
  Android). Not a rejection reason; a branded launch screen is a design item.
- Store screenshots do not exist: iPhone 6.9-inch set (and 13-inch iPad if iPad stays), at least two
  phone screenshots for Play. They need a signed-in demo tenant (§9).

### 2.4 Permissions — declared vs. used

What the code really does (same shared core in every app):

| Capability | Used by | iOS | Android |
|---|---|---|---|
| Camera | profile photo; photo / document / barcode capture in forms (all apps); business-card scan (CRM); receipt scan (PHR); fault photos (FixFlow) | `NSCameraUsageDescription` ✅ (PEM 🔧 added) | none needed — the system camera is opened through an intent, the apps hold no `CAMERA` permission ✅ |
| Photo library | choose profile photo; attach pictures (all apps) | `NSPhotoLibraryUsageDescription` ✅ (PEM 🔧 added) | none needed (system picker) ✅ |
| Location, **while in use only** | Site map and nearby Sites (PMS); workplace clock-in / out (PHR); field-work start / end position and map (FixFlow); location field of forms and dashboard weather widget (all apps) | `NSLocationWhenInUseUsageDescription` ✅ (CRM, PPM, PEM 🔧 added) | `ACCESS_COARSE_LOCATION` + `ACCESS_FINE_LOCATION` 🔧 added in all six — none was declared, so every location request failed |
| Location in the background | **not used** — geofence attendance reads the position only while the app is open | no "Always" key, no `location` background mode ✅ | no `ACCESS_BACKGROUND_LOCATION` ✅ |
| Notifications | remote push on iOS (APNs); local notifications (clock-in / out) | runtime prompt; `remote-notification` background mode ✅ | `POST_NOTIFICATIONS` + `VIBRATE` (merged from the notifications plugin) ✅ |
| Biometrics | optional biometric sign-in | `NSFaceIDUsageDescription` ✅ | `USE_BIOMETRIC` (merged) ✅; `MainActivity` 🔧 now a `FlutterFragmentActivity` (required by the plugin — it could not work before) |
| Network | all traffic HTTPS | ATS on, no exceptions ✅ | `INTERNET`, `ACCESS_NETWORK_STATE`; cleartext disabled ✅ |
| Microphone, Bluetooth, contacts, calendar, tracking (IDFA) | **not used** | no keys ✅ | no permissions ✅ |

To verify on first upload: App Store Connect sometimes asks for `NSMicrophoneUsageDescription`
(the image-picker binary contains video capture) and `NSLocationAlwaysAndWhenInUseUsageDescription`
(the location plugin contains the "Always" request). Neither is used by the apps. If the upload
e-mail asks for them: for "Always", set the plugin's compile flag `BYPASS_PERMISSION_LOCATION_ALWAYS=1`
in the `Podfile` `post_install` block rather than adding a key for a permission the apps never
request.

#### Purpose strings (exact texts — now in `Info.plist` (en) and `Runner/{en,tr}.lproj/InfoPlist.strings`) 🔧

Face ID — all apps
- en: Face ID is used to sign you in quickly and securely.
- tr: Uygulamaya hızlı ve güvenli giriş için Face ID kullanılır.

| App | Key | English | Türkçe |
|---|---|---|---|
| PMS | Camera | The camera is used to scan barcodes and QR codes and to add photos to forms and to your profile. | Kamera; barkod ve QR kod okutmak, formlara ve profilinize fotoğraf eklemek için kullanılır. |
| PMS | Photos | Your photo library is used to choose a barcode or QR image and to attach pictures to forms and to your profile. | Fotoğraf arşiviniz; barkod veya QR görseli seçmek, formlara ve profilinize görsel eklemek için kullanılır. |
| PMS | Location | Your location is used to show where you are on the Site map, to find nearby Sites and to fill location fields in forms. | Konumunuz; Site haritasında bulunduğunuz yeri ve yakındaki Siteleri göstermek, formlardaki konum alanlarını doldurmak için kullanılır. |
| CRM | Camera | The camera is used to scan business cards and to add photos to records and to your profile. | Kamera; kartvizit taramak, kayıtlara ve profilinize fotoğraf eklemek için kullanılır. |
| CRM | Photos | Your photo library is used to choose a business card image and to attach pictures to records and to your profile. | Fotoğraf arşiviniz; kartvizit görseli seçmek, kayıtlara ve profilinize görsel eklemek için kullanılır. |
| CRM | Location | Your location is used to fill location fields in forms and to show local weather on your dashboard. | Konumunuz; formlardaki konum alanlarını doldurmak ve panonuzda yerel hava durumunu göstermek için kullanılır. |
| PHR | Camera | The camera is used to scan expense receipts and to add photos to forms and to your profile. | Kamera; masraf fişlerini taramak, formlara ve profilinize fotoğraf eklemek için kullanılır. |
| PHR | Photos | Your photo library is used to choose a receipt image and to attach pictures to forms and to your profile. | Fotoğraf arşiviniz; fiş görseli seçmek, formlara ve profilinize görsel eklemek için kullanılır. |
| PHR | Location | Your location is used while the app is open to confirm that you are at your workplace when you clock in or out, and to fill location fields in forms. | Konumunuz, uygulama açıkken giriş ve çıkış kaydınızda iş yerinde olduğunuzu doğrulamak ve formlardaki konum alanlarını doldurmak için kullanılır. |
| PPM | Camera | The camera is used to scan barcodes and QR codes and to add photos to tasks, forms and your profile. | Kamera; barkod ve QR kod okutmak, görevlere, formlara ve profilinize fotoğraf eklemek için kullanılır. |
| PPM | Photos | Your photo library is used to attach pictures to tasks and forms and to choose your profile photo. | Fotoğraf arşiviniz; görevlere ve formlara görsel eklemek, profil fotoğrafınızı seçmek için kullanılır. |
| PPM | Location | Your location is used to fill location fields in forms and to show local weather on your dashboard. | Konumunuz; formlardaki konum alanlarını doldurmak ve panonuzda yerel hava durumunu göstermek için kullanılır. |
| FixFlow | Camera | The camera is used to take photos of the fault and of the work done, and to scan barcodes and QR codes. | Kamera; arızanın ve yapılan işin fotoğrafını çekmek, barkod ve QR kod okutmak için kullanılır. |
| FixFlow | Photos | Your photo library is used to attach pictures to a request and to choose your profile photo. | Fotoğraf arşiviniz; talebe görsel eklemek ve profil fotoğrafınızı seçmek için kullanılır. |
| FixFlow | Location | Your location is used while the app is open to record where field work starts and ends, to show your position on the map and to fill location fields in forms. | Konumunuz, uygulama açıkken saha işinin başladığı ve bittiği yeri kaydetmek, haritada konumunuzu göstermek ve formlardaki konum alanlarını doldurmak için kullanılır. |
| PEM | Camera | The camera is used to add photos to forms and to your profile. | Kamera; formlara ve profilinize fotoğraf eklemek için kullanılır. |
| PEM | Photos | Your photo library is used to attach pictures to forms and to choose your profile photo. | Fotoğraf arşiviniz; formlara görsel eklemek ve profil fotoğrafınızı seçmek için kullanılır. |
| PEM | Location | Your location is used to fill location fields in forms and to show local weather on your dashboard. | Konumunuz; formlardaki konum alanlarını doldurmak ve panonuzda yerel hava durumunu göstermek için kullanılır. |

German and Italian users see the English prompt (`CFBundleLocalizations` lists en, tr, de, it; only
en and tr have an `InfoPlist.strings`). Adding `de.lproj` / `it.lproj` is a translation task.

### 2.5 Privacy, encryption, deep links, push

| | PMS | CRM | PHR | PPM | FixFlow | PEM |
|---|---|---|---|---|---|---|
| iOS privacy manifest (`PrivacyInfo.xcprivacy`) | ✅ | ✅ 🔧 location | ✅ | ✅ 🔧 location | ✅ 🔧 location | 🔧 added |
| `ITSAppUsesNonExemptEncryption = false` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Custom URL scheme (Microsoft connect return) | — | `ptbcrm` ✅ | — | — | `ptbfixflow` ⛔ not accepted by the server | — |
| App / universal links declared in the app | — | `app.crm.protoolbag.com` | — | — | `app.fixflow.protoolbag.com` | `app.pem.protoolbag.com` |
| Association files served by the web host | n/a | ❓ to verify | n/a | n/a | ❓ | ❓ |
| iOS push (APNs, `aps-environment = production`) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Android remote push | ⚠️ none | ⚠️ none | ⚠️ none | ⚠️ none | ⚠️ none | ⚠️ none |
| Privacy policy reachable in the app | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 | 🔧 |
| Account deletion | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ |

Details in §3–§8.

---

## 3. iOS privacy manifest and required-reason APIs

The app-level manifest of each app declares: **no tracking, no tracking domains**; collected data
(all linked to the user, purpose "app functionality" only): name, e-mail address, phone number, user
id, device id (APNs token), photos or videos, other user content, crash data, precise location;
PHR additionally "other financial info" (payslips). Required-reason API of the app's own code:
`UserDefaults` — `CA92.1` (the app reads and writes only its own preferences).

Third-party code in the binary (identical in all six apps; resolved versions from `pubspec.lock`):

| Plugin (iOS) | Ships its own privacy manifest | Note |
|---|---|---|
| app_links 6.4.1, connectivity_plus 7.3.1, file_picker 11.0.3, flutter_secure_storage 9.2.4, geocoding_ios 3.1.0, geolocator_apple 2.4.3, image_picker_ios 0.8.13+15, local_auth_darwin 1.6.1, package_info_plus 9.0.1, sqflite_darwin 2.4.6, url_launcher_ios 6.4.2 | yes | — |
| flutter_local_notifications 18.0.1, shared_preferences_foundation 2.6.2 | yes — `UserDefaults` | merged into the app's privacy report by Xcode |
| google_mlkit_commons 0.8.1, google_mlkit_text_recognition 0.13.1, google_mlkit_barcode_scanning 0.12.1 | **no** (the wrapper plugins) | the underlying Google ML Kit pods carry Google's own manifests — **to verify** in the archive's privacy report (Xcode → Organizer → Generate Privacy Report) |
| image_cropper 12.2.1, path_provider_foundation 2.6.0 | **no** | to verify in the same report; path_provider reads no required-reason API in the app's use |

What to do with the first archive: generate the privacy report, confirm that every required-reason
API listed has a reason, and that no SDK from Apple's "commonly used SDKs" list is present without a
manifest and signature. This cannot be checked without a build.

No analytics SDK, no advertising SDK, no crash-reporting SDK is linked. Client errors go to the
product's own back end (`log-client-error`), release builds only.

---

## 4. Privacy answers for the two store forms

Derived from what the code collects and sends. The answers are the same for all six apps except
where a row names an app. "Shared" means sent to a party other than the product's own back end.

Where data goes

| Destination | What | When |
|---|---|---|
| Product back end (same Supabase project as the web app, EU region) | everything in the table below | signed-in use |
| Apple Push Notification service | device push token (iOS) | after the user allows notifications |
| Open-Meteo (weather API, no account, no key) | latitude / longitude of the dashboard weather widget — the configured place, or the device position if the user allowed location | when a dashboard with the weather widget is shown |
| Map tile servers (CARTO basemaps; Esri World Imagery for satellite view) | the map tiles requested, i.e. the area being viewed, and the device's IP address | when a map is shown (PMS, PHR clock-in map, FixFlow) |
| Microsoft Graph, through the product's server-side proxy | the user's own Microsoft 365 mail / files / calendar / Teams / Planner calls | only after the user connects a Microsoft account |
| Language-model providers, through the product's server | the text the user sends to the AI assistant and the record context the server adds | when the user uses the AI assistant |
| On-device only | text recognition and barcode reading (ML Kit runs on the device; images are not uploaded for recognition) | scanning |

Collected data

| Data | Collected | Purpose | Linked to user | Optional | App Store label | Play Data safety type |
|---|---|---|---|---|---|---|
| Name | yes | app functionality, account management | yes | no | Contact Info → Name | Personal info → Name |
| E-mail address | yes (sign-in) | app functionality, account management | yes | no | Contact Info → Email Address | Personal info → Email address |
| Phone number | yes, if entered in the profile | app functionality | yes | yes | Contact Info → Phone Number | Personal info → Phone number |
| User id | yes | app functionality | yes | no | Identifiers → User ID | Personal info → User IDs |
| Device push token | iOS only | app functionality (notifications) | yes | yes (permission) | Identifiers → Device ID | Device or other IDs (Android: **not collected** — no remote push) |
| Precise location | yes, while in use | app functionality | yes | yes (permission) | Location → Precise Location | Location → Precise location |
| Photos | yes (profile photo, attachments, scanned documents) | app functionality | yes | yes | User Content → Photos or Videos | Photos and videos → Photos |
| Files and documents | yes (attachments) | app functionality | yes | yes | User Content → Other User Content | Files and docs |
| Records, comments, form entries, AI assistant messages | yes | app functionality | yes | — | User Content → Other User Content | App activity → Other user-generated content |
| Customer / contact records entered by the user (CRM) | yes | app functionality | yes | — | Contacts (business contacts typed or scanned by the user — the device address book is **not** read) → **to verify** whether Apple's "Contacts" type applies; declare it if in doubt | Personal info → Other info |
| Employment and payroll data (PHR: payslips, leave, attendance; national id / IBAN only shown, never typed in the app) | yes (displayed and stored by the employer's HR) | app functionality | yes | no | Financial Info → Other Financial Info; Sensitive Info **to verify** | Financial info → Other financial info |
| Health data (PHR: blood type field on the personal profile, shown to the person and to authorised HR) | displayed, not entered in the app | app functionality | yes | — | Health & Fitness → Health **to verify with the DPO** | Health info **to verify** |
| Crash / error diagnostics (message, stack trace, app version, platform code) | yes, release builds | app functionality (diagnostics) | yes | no | Diagnostics → Crash Data | App info and performance → Crash logs, Diagnostics |
| Usage analytics, advertising data, tracking, purchases, browsing / search history, audio, device contacts, calendar | **no** | — | — | — | not collected | not collected |

Form-level answers

- **Tracking (Apple):** No. No data is used to track the user across apps or websites of other
  companies; no advertising identifier is read.
- **Is data encrypted in transit (Play)?** Yes — HTTPS only (ATS without exceptions; Android cleartext
  disabled).
- **Can users request deletion (Play)?** Today: **no self-service path** → blocker B1. The form
  cannot be completed truthfully until a deletion URL exists.
- **Is data shared with third parties (Play)?** Location coordinates with the weather provider and
  viewed-area requests with the map tile providers are transfers to third parties; whether Play's
  "service provider" exemption covers them, and how the AI assistant's language-model providers are
  to be declared, is a legal classification: **to verify with the DPO**. Apple (guideline 5.1.2)
  expects the user to be told, and to agree, before personal data is sent to a third-party AI
  service: the AI assistant needs a disclosure / consent step, or must be switched off in the store
  builds — **owner decision**.
- **Independent security review (Play):** no.
- **Children / target audience:** business users only; not directed at children. Age rating
  questionnaire: no objectionable content, no user-generated content shown to the public.

---

## 5. Export compliance

`ITSAppUsesNonExemptEncryption = false` in all six `Info.plist` files. That is correct as long as
the apps use only the operating system's cryptography and standard protocols: HTTPS / TLS through
the system stack, Keychain / Keystore storage, the system's biometric API. No proprietary or
non-standard cryptographic algorithm is implemented or bundled. Review the answer if a custom
cryptographic library is ever added.

---

## 6. Deep links

### 6.1 What is configured

| Kind | Apps | Configuration |
|---|---|---|
| Custom scheme `<scheme>://oauth-callback` (return of the Microsoft connect flow) | CRM `ptbcrm`, FixFlow `ptbfixflow` | Android intent filter, iOS `CFBundleURLTypes`, `CoreConfig.appUrlScheme` |
| https links `https://app.<code>.protoolbag.com/<path>` | CRM, FixFlow, PEM | Android `autoVerify` intent filter for the whole host; iOS `applinks:` entitlement |
| none | PMS, PHR, PPM | the apps neither declare a domain nor register a scheme |

### 6.2 Files the web hosts must serve

Templates with placeholders are in [`well-known/`](well-known/) — one folder per host, see its
README for the placeholders (Play app-signing SHA-256 fingerprint, Apple team id) and the serving
rules. Whether the hosts already serve them: **to verify** (`curl -I
https://app.crm.protoolbag.com/.well-known/assetlinks.json` must return 200 and JSON, not the web
app's `index.html`).

### 6.3 Findings

- **The server does not accept FixFlow's scheme.** `oauth-start` / `oauth-callback` only return to
  `ptbcrm:`, `ptbphr:`, `ptbpms:`, `ptbppm:`, `ptbmobile:` (`MOBILE_SCHEMES` in
  `supabase/functions/_shared/oauth-flow.ts`). FixFlow sends `ptbfixflow://oauth-callback`, which is
  replaced by the web fallback page: the Microsoft connect flow started in the FixFlow app ends on
  the PMS web site and never returns to the app. **Web-side change:** add `ptbfixflow:` to the list
  (and `ptbpem:` if PEM is to offer the flow).
- **PHR, PMS and PPM have a server-side scheme but none in the app**, and do not start the link
  listener; Microsoft cannot be connected from these apps (the screens now say "connect on the web"
  instead of a generic failure). The connection made on the web is used by the app.
- **A verified https association claims the whole host.** Every link to the web app then opens the
  mobile app — including invitation and password-reset e-mails (`/auth/…`) and pages that only exist
  on the web. Before this lane such a link did nothing at all inside the app. It now opens a screen
  that says the page is in the web app, with **Open on the web** 🔧. The iOS template excludes the
  web-only paths so those links stay in the browser; on Android the equivalent is to narrow the
  intent filter to the paths the app handles (not done — it needs the list of paths per app and a
  device test).

---

## 7. Push

- **iOS:** direct APNs, no intermediary SDK. `AppDelegate` registers on request from the shell,
  the token is stored in `user_devices`, the server sends. Entitlement `aps-environment =
  production`, background mode `remote-notification`. Owner side: an APNs auth key (`.p8`) in the
  server's secrets and the Push Notifications capability on each App ID. End-to-end delivery:
  **to verify on a device**.
- **Android:** there is **no remote push**. No messaging SDK is linked and no token is produced;
  only local notifications exist (clock-in / out). Either accept it for the first release and say so
  in the listing (the drafts do not promise push on Android), or add a push transport — a
  development item, not configuration.
- A notification tap while the app is not running does not route to the target screen yet (known
  gap in the roadmap).

---

## 8. Account deletion (blocker B1)

- **In the apps:** none. Settings has sign-out only. PHR's "My data" screen is a read-only overview
  of processed categories and consents.
- **On the web:** none for the signed-in user. The web has `remove-user` (a tenant administrator
  removes a member) and `tenant-erasure` (operator console).
- **What both stores need:** an entry in the app (Settings → Account → "Delete my account" or
  "Request account deletion") that either deletes or files a request, and a public web page that
  explains how to request deletion without the app (Play's Data safety form asks for its URL).
- **Minimum that fits the product** (accounts belong to the customer organisation): a "request
  account deletion" action that records the request, notifies the tenant administrator and the
  operator, and is fulfilled with the existing `remove-user` path within a stated period; plus a
  public page on the website describing the same. This needs a server-side function, a decision on
  retention of business records the person created, and legal wording — **owner decision; not
  started**.

---

## 9. Reviewer access (blocker B3)

Reviewers of both stores sign in with credentials entered in the console. No account was created in
this lane.

| Need | Recommendation |
|---|---|
| Tenant | One dedicated demo tenant with seeded, clearly fictitious data and a licence for all six platforms (the apps show a licence screen when the tenant does not own the platform). Not the internal tenant. |
| Role | `ROLE_USER`. Most menu rows of every platform are open to it (live `platform_menu_items`: 32–81 open rows per platform, 5–11 admin-only). An administrator account is not needed and would show configuration menus that mostly point at the web. |
| Second factor | The tenant's `mfa_policy.enforce_for` must be `off` or `optional` — a reviewer cannot receive a mailed code or hold an authenticator. The apps follow the tenant policy today. |
| Consent gate | Accept the KVKK / terms consent for the account beforehand, or leave it so the reviewer sees and accepts it — decide and say so in the review notes. |
| Data per app | PMS: a few Sites with controllers, variables and some active and historical alarms. CRM: Firma, kişi, Potansiyel, Fırsat on the Satış Hattı, a few activities. PHR: a staff record for the reviewer with leave balance, payslips, attendance, one pending approval, a geofence. PPM: a project with a board, backlog, sprint and work logs. FixFlow: a few Talep in different states, one assigned to the reviewer. PEM: meters with consumption history and alarms. |
| Things a reviewer cannot do | Microsoft 365 connection (needs their own Microsoft account — say in the notes that it is optional); workplace clock-in (needs to be inside the geofence — give the demo geofence a very large radius or describe it in the notes); biometric sign-in on their device works without preparation. |
| Review notes | State that accounts are created by the customer's administrator (no self-registration), give the credentials, say which features need hardware or a third-party account, and — once B1 is solved — where account deletion is. |

---

## 10. Per-app checklists

Common to all six — **owner steps**

- [ ] B1 account deletion: decision, server flow, in-app entry, public web page.
- [ ] B2 Android signing: create the upload keystore, add `android/key.properties` (git-ignored) and
      a `release` signing config that reads it; enrol in Play App Signing; record the app-signing
      SHA-256 for `assetlinks.json`.
- [ ] B3 reviewer tenant and accounts (§9).
- [ ] Decide the Android application ids (`com.protoolbag.<code>` recommended) **before** the first
      upload.
- [ ] Decide iPad support (layout pass + iPad screenshots, or iPhone only).
- [ ] App Store Connect: create the six app records (bundle ids above), enable Push Notifications
      and — where declared — Associated Domains on each App ID; APNs key on the server.
- [ ] Play Console: create the six apps; target audience, content rating, Data safety (§4), privacy
      policy URL, app access (credentials), ads declaration = no. Developer account type and any
      closed-testing prerequisite for a new account: **to verify**.
- [ ] Privacy policy URL and support URL for the listings (public pages; the app links to
      `https://app.<code>.protoolbag.com/legal/privacy-policy` and `/legal/terms-of-service` — to
      verify that these open without sign-in on every host).
- [ ] AI assistant: disclosure / consent before sending data to a third-party model provider, or
      disable it in the store builds (§4).
- [ ] DPO review of §4 (health and financial data types, third-party transfers).
- [ ] Icons: Play 512 px icon, feature graphic, adaptive icon layers; screenshots for both stores.
- [ ] Apply the proposed keywords on the web side
      (`docs/proposed-sql/20261113_mobile_store_prep_keywords.sql`).
- [ ] First archive of each app: privacy report (§3), 16 KB check on the AAB, purpose-string
      e-mail from App Store Connect, biometric prompt on Android 7 / 8 (the window theme is still a
      platform theme; the biometric dialog on API 24–27 expects an AppCompat theme — to verify).
- [ ] Serve the association files (§6.2) for the hosts whose apps declare the domain.

Common — **done in this lane** (§11): display names, purpose strings en / tr with the missing keys,
PEM privacy manifest, precise-location declaration, Android location permissions, Android
`FlutterFragmentActivity`, Android brand icons, privacy-policy and terms links and real version in
Settings, release scripts for FixFlow / PEM, association-file templates, listing drafts.

### PMS — Protoolbag PMS
- Owner: common list. Association files only matter if the app is to declare
  `app.pms.protoolbag.com` (it does not today).
- Open: no Microsoft connect from the app (connect on the web); iOS deployment target 13.0 vs. ML Kit
  pods (to verify).
- Done: iOS display name "Protoolbag Pms" → "Protoolbag PMS"; Android label; Site and provider
  screens no longer show "0 active alarms" when the alarm read failed.

### CRM — Protoolbag CRM
- Owner: common list; serve `assetlinks.json` and the association file on `app.crm.protoolbag.com`.
- Open: iOS deployment target 13.0 (to verify); `CFBundleURLName` still reads
  `com.protoolbag.exampleCrm.oauth` (cosmetic, not shown to users).
- Done: Android label; location purpose string; Microsoft states (declined consent, administrator
  approval, missing permission, throttling) instead of empty lists.

### PHR — Protoolbag HR
- Owner: common list. The Android application id `com.protoolbag.example_phr` is the one most in
  need of renaming. DPO: payroll and special-category data in the labels (§4).
- Open: geofence clock-in is foreground only — say so in the review notes; reviewers cannot be
  inside the geofence.
- Done: Android label; clean "no access" states for the narrowed manager scope.

### PPM — Protoolbag PM
- Owner: common list.
- Open: no Microsoft connect from the app although the Planner link card is shown on projects
  (it works with a connection made on the web).
- Done: Android label; location purpose string; Planner plan list shows why it could not be read.

### FixFlow — Protoolbag FixFlow
- Owner: common list; **own app icon** (it uses CRM's); serve the association files on
  `app.fixflow.protoolbag.com`; no `Podfile.lock` committed — the first `pod install` decides the
  pod versions (commit the lock afterwards).
- ⛔ Web-side: add `ptbfixflow:` to the server's allowed return schemes, otherwise Microsoft connect
  from this app cannot return (§6.3).
- Done: release scripts accept `fixflow`; location purpose string covers field-work positions;
  precise location declared in the privacy manifest.

### PEM — Protoolbag PEM
- ⛔ **iOS project is not release-ready**: no `ios/ExportOptions.plist`; `DEVELOPMENT_TEAM` is
  `5F37BRKPX9`, the other five use `283AHKB4WM`; no `Podfile.lock`. PEM's project is the only one
  set up for Swift packages, and package resolution fails today: *"image_cropper 12.2.1 depends on
  TOCropViewController 3.1.2..<4.0.0 and DKImagePickerController (file picker) depends on
  TOCropViewController 2.6.0..<3.0.0"* (reported by `xcodebuild -list`, which only reads the
  project). Options: turn Swift package integration off for this app (`flutter: config:
  enable-swift-package-manager: false` in its `pubspec.yaml`) so it uses CocoaPods like the other
  five, or align the two plugins. **To verify with a build; owner decides the team.**
- Owner: common list; serve the association files on `app.pem.protoolbag.com`.
- Done: privacy manifest; camera / photo / location purpose strings (the profile photo picker would
  have crashed without them); the web-only setup wizard is hidden from the mobile menu; alarm
  priorities with `active IS NULL` are no longer dropped.

---

## 11. What was changed in the repository for store readiness

| Commit subject | Effect |
|---|---|
| `fix(ios): privacy manifests — add PEM's, declare precise location where it is collected` | PEM manifest; location declared for CRM, PPM, FixFlow, PEM |
| `fix(apps): store display names — Android labels and the PMS iOS name` | names as in §2.1 |
| `fix(ios): permission purpose strings in English and Turkish, missing keys added` | §2.4 texts, `InfoPlist.strings`, `CFBundleLocalizations` |
| `fix(android): declare foreground location permission in the six apps` | location works on Android |
| `fix(android): MainActivity extends FlutterFragmentActivity (biometric sign-in)` | biometric sign-in can work on Android |
| `fix(android): launcher icons use each app's brand icon instead of the Flutter default` | brand icons in five densities |
| `chore(scripts): release scripts accept FixFlow (and PEM on Android)` | build scripts cover all apps that can be built |
| `feat(settings): privacy policy and terms links, real app version, translated section titles` | policy reachable in the app; no hardcoded version |

None of these was build-verified (no builds in this lane). Static checks that were run:
`plutil -lint` on every changed plist, strings file and Xcode project; `xmllint` on the manifests;
`xcodebuild -list` on the PMS and CRM projects; `flutter analyze` and `flutter test` for the Dart
side.

---

## 12. Other findings that affect a store release

- **Languages.** The stores will list English, Turkish, German and Italian. About 100 visible texts
  in the shared screens are still literal Turkish (counted with a pattern search; the real number is
  higher because many texts use a Turkish fallback when a keyword is missing), and 8 source files
  format dates or numbers with a fixed Turkish locale (`formatters.dart`, `date_extensions.dart`,
  `dyn_widget_helpers.dart`, `core_initializer.dart`, `mobile_menu_service.dart`,
  `login_screen.dart`, CRM `crm_record.dart`, PHR `ess_common.dart`). A reviewer using the English
  listing will meet Turkish screens. Either list only Turkish for the first release, or finish the
  keyword pass first.
- **Second factor for administrators.** The web app requires a second factor for every
  administrator (`fn_my_mfa_requirement`); the mobile apps follow only the tenant's `mfa_policy`, so
  an administrator of a tenant without a policy signs in on mobile without the second factor. Not
  changed here (it would gate every administrator at the next sign-in and could not be tested);
  it should be aligned before release.
- **Help.** Settings → Help and support still says "coming soon"; both listings need a support URL.
- **`.env` is bundled as an asset** (Supabase URL and publishable key, by design). Nothing secret
  may ever be put in that file — it ships inside the app.

---

## 13. Recommended release order

Order by how complete the app is on the phone, how little it depends on unfinished items, and how
much review risk it carries.

1. **FixFlow** and **CRM** first, together — they are the two apps of the controlled pilot, have
   the most complete mobile surface and already carry deep-link configuration. FixFlow needs its own
   icon and the server-side scheme fix; CRM needs nothing app-specific.
2. **PMS** — complete monitoring surface; no deep-link work; the alarm screens were hardened here.
3. **PPM** — smaller surface (board, backlog, sprints, work logs, my work); low review risk.
4. **PHR** — last of the five that build today: it handles payroll and special-category data, so
   the privacy labels need the DPO's sign-off, and geofence clock-in needs the most explanation to
   reviewers.
5. **PEM** — after its iOS project is made buildable (team, export options, package resolution).

Before any of them: B1, B2, B3. A sensible first step that needs none of the three is an **internal
TestFlight build** of FixFlow and CRM (internal testers do not go through App Review) to verify the
items marked "to verify" on a device, followed by a Play internal-testing track once the upload key
exists.
