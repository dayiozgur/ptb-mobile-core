import 'package:protoolbag_core/protoolbag_core.dart';

/// FIXFLOW platform kimliği (canlı DB: `platforms.code = 'FIXFLOW'`). Bu app
/// DAİMA FixFlow platformunda açılır — menü (`platform_menu_items`,
/// menu_source='db') + entity'ler bu platformdan yüklenir.
const String kFixflowPlatformId = 'b1f1f10f-0000-4000-8000-000000000001';

/// `platforms.code` — [PlatformContext.setActivePlatform]'a verilir.
const String kFixflowPlatformCode = 'FIXFLOW';

/// Bu app'in sahibi olduğu universal-link host'u (assetlinks / AASA bu host'ta
/// barındırılmalı). `https://app.fixflow.protoolbag.com/<path…>` → uygulama-içi ekran.
const String kFixflowAppLinkHost = 'app.fixflow.protoolbag.com';

bool _done = false;

/// FixFlow ekranlarını çekirdek [ScreenResolver]'a kaydet (bir kez, idempotent).
///
/// Domain mantığı tamamen çekirdektedir (`registerFixflowScreens()` →
/// `/fixflow`, `/fixflow/tickets`, `/fixflow/work-requests`,
/// `/fixflow/maintenance`, `/fixflow/sla`, `/fixflow/approvals` ve
/// `/fixflow/tickets/<id>` deep-link'i). İlk shell render'ından ÖNCE
/// `main()` içinde çağrılmalı; aksi halde bu yollar `hasScreen=false` olur ve
/// menüden budanır.
void registerFixflowAppScreens() {
  if (_done) return;
  registerFixflowScreens();
  registerMicrosoftFilesSection(); // OneDrive/SharePoint dosya kartı (tüm tipler)
  _done = true;
}
