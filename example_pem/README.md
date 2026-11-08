# protoolbag_pem — Protoolbag PEM (mobil)

PEM (Protoolbag Energy Management) ürününün bağımsız mobil uygulaması.
Paylaşılan çekirdeği (`protoolbag_core`, `../`) kullanır: giriş, kiracı/organizasyon
seçimi, DB-güdümlü menü (`platform_menu_items`, PEM platformu), lisans, KVKK onay
kapısı, push ve markalama çekirdekten gelir. PEM'e özgü ekranlar
`lib/features/` altında ve `lib/config/pem_screens.dart` ile çekirdek
`ScreenResolver`'a kaydedilir.

## Yapılandırma (kullanıcı sağlar, gitignore'da)

- `.env` — `SUPABASE_URL`, `SUPABASE_ANON_KEY`, isteğe bağlı `API_BASE_URL`,
  `APP_NAME`, `DEBUG_MODE`.
- `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` — push
  (Firebase) yapılandırması.

## Mobil ekranlar (v1, salt-okunur)

| Menü yolu | Ekran | Veri kaynağı |
|---|---|---|
| `/admin/energy/dashboard`, `/admin/energy/cockpit` | Enerji panosu | `fn_energy_consumption_rollup`, `fn_pms_energy_by_dimension`, `alarms` (ENERGY_*), `energy_readings_rollup` |
| `/admin/energy/benchmarking`, `/admin/energy/consumption` | Saha listesi → saha enerji detayı | `sites`, `fn_energy_site_benchmark`, `energy_readings_rollup`, `energy_meters`, `fn_energy_load_profile` |
| `/admin/energy/alarms` | Enerji alarmları | `alarms` (ENERGY_*), `priorities` |
| `/admin/energy/anomalies` | Tüketim anomalileri | `fn_energy_consumption_anomalies` |
| `/admin/energy/load-profile` | Yük profili | `fn_energy_load_profile` |
| `/admin/energy/meters` | Sayaçlar | `energy_meters`, `sites` |
| `/admin/energy/reports` | Enerji raporları | çekirdek `ReportViewerScreen` (`pem-energy-overview`) |

## Test

```
TZ=UTC flutter test
```
