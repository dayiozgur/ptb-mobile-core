# iPhone'da Test — Kurulum Rehberi (Protoolbag PMS)

Uygulama + Supabase bağlantısı hazır. iOS'ta fiziksel telefonda çalıştırmak için aşağıdaki adımlar. **⚙️ = senin yapacağın (Xcode/Apple ID), ✅ = hazır.**

## Durum
- ✅ Flutter 3.38 kurulu, `example_pms` çalıştırılabilir (tüm platform dizinleri var).
- ✅ Supabase config canlı projeye bağlı (`example_pms/.env` — URL + anon key doğru).
- ✅ iOS ayarları: bundle id `com.protoolbag.pms.protoolbagPms`, min iOS **13.0**, Pod'lar kurulu.
- ✅ İzin string'leri eklendi: **Konum** (harita) + **Face ID / Touch ID** (biyometrik giriş). Kamera/foto gerekmiyor (o alan-tipleri mobilde kullanılmıyor).
- ⚙️ Eksik: tam **Xcode** kurulumu + **Apple ID ile imzalama** (yalnız sen yapabilirsin).

## Adımlar

### 1. ⚙️ Xcode'u tam kur
App Store'dan **Xcode** (~7GB) kur, sonra terminalde:
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```
Doğrula: `flutter doctor` → Xcode satırı `[✓]` olmalı.

### 2. ✅ Bağımlılıklar + Pod'lar
```bash
cd /Users/ozgurdayi/IdeaProjects/ptb/ptb-mobile-core/example_pms
flutter pub get
cd ios && pod install && cd ..
```
(Pod'lar zaten kurulu; Xcode tamamlandıktan sonra `pod install`'ı bir kez daha çalıştır.)

### 3. ⚙️ Apple ID + imzalama (Xcode)
```bash
open ios/Runner.xcworkspace
```
Xcode'da:
1. **Xcode > Settings > Accounts** → **+** → Apple ID'nle giriş yap (ücretsiz hesap yeter — 7 günlük geçici sertifika).
2. Sol panelde **Runner** projesini seç → **Signing & Capabilities** sekmesi → **Runner** target'ı.
3. **Automatically manage signing** işaretli olsun → **Team** = Apple ID'n.
4. Bundle id çakışırsa (başkası almışsa): sonuna kısaltma ekle, ör. `com.protoolbag.pms.protoolbagPms.oz`.

### 4. ⚙️ iPhone'u bağla + güven
1. iPhone'u **USB** ile Mac'e bağla.
2. Telefonda çıkan **"Bu bilgisayara güven?"** → **Güven** + şifre.
3. iPhone'da **Ayarlar > Gizlilik ve Güvenlik > Geliştirici Modu** → **Aç** (iOS 16+), telefon yeniden başlar.
4. Doğrula: `flutter devices` → iPhone'un listede görünmeli.

### 5. ✅ Çalıştır
```bash
flutter run --release -d <iphone-cihaz-id>
```
(`flutter devices` çıktısındaki iPhone id'sini yaz. İlk kurulumda debug yerine `--release` daha akıcı.)

İlk açılışta iPhone "Güvenilmeyen Geliştirici" derse:
**Ayarlar > Genel > VPN ve Cihaz Yönetimi** → Apple ID'ni **Güven**.

### 6. Test
- Giriş: e-posta/şifre **veya** Face ID (izin string'i hazır).
- PMS: dashboard sayaçları, site/provider/controller/variable gezinme, alarm listesi + **artık alarm onayla/sıfırla/bastır** (bu oturumda bağlandı), harita, telemetri grafikleri.

## Notlar / sınırlar
- **Ücretsiz Apple ID:** uygulama **7 gün** sonra açılmaz → `flutter run` ile yeniden yükle. Ücretli ($99/yıl) → 1 yıl + **TestFlight** (kablosuz dağıtım, USB'siz).
- **Davet linki (accept-invite):** e-postadaki davet linkinin uygulamayı açması için iOS **Universal Links** (Associated Domains + sunucuda `apple-app-site-association`) gerekir — bu DNS/sunucu işi, ilk testte gerekmez (şifreyle giriş yeterli). Sonraki adım olarak hazırlanır.
- **Push bildirim:** henüz uçtan uca bağlı değil (FCM/APNs) — ayrı iş.
- Sorun olursa: `flutter run -v` çıktısını paylaş.
