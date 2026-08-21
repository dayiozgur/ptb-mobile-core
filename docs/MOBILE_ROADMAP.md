# Protoolbag Mobile-Core — Web Parity Roadmap

> **Amaç:** Web portalındaki **tüm dinamik / db-driven** özellikleri `protoolbag_core` (paylaşılan kernel) içine taşımak. Her platform (PHR·PPM·PMS·PEM·CRM) çekirdek üzerinde çalışan **ince bir app**. Core'da bir geliştirme → tüm platformlar kazanır (WindowsOS modeli). Backend **aynı Supabase projesi** — mobil, web'in EF/RPC sözleşmelerini birebir çağırır, **ayrı config yok**.

**Kaynak:** Bu yol haritası, web (`protoolbag-platform`) ↔ mobil (`ptb-mobile-core`) paralel-ajan analizlerine dayanır. Olgunluk (mobil-vs-web, ESS/monitoring app'i için ağırlıklı): **~%75** (çekirdek kernel ~%85, web read-write paritesinde).

---

## 0. Şu ana kadar tamamlanan (temel + bu oturum)

| Alan | Durum |
|---|---|
| Auth / session (biometrik, invite, cold-start) | ✅ ~90 |
| DB-menü + navigasyon | ✅ ~90 |
| **Global app-shell** (dinamik sidebar + üst-bar arama/AI/bildirim/platform + Ana Sayfa·My Space·Profil·Ayarlar) | ✅ |
| Entity-engine (list/detail/form, read-write) | ✅ ~82 |
| Dinamik form (14 field tipi) | ✅ ~85 |
| Profil hub + LinkedIn drawer + avatar (signed-URL) | ✅ |
| Login yeniden-tasarım | ✅ |
| Bildirimler | ✅ ~90 |
| Storage / signed-URL | ✅ ~85 |
| **AI Asistan** (`ai-assistant` EF) | ✅ |
| **Global arama** (`fn_universal_search`) | ✅ |
| **Entity status Kanban (drag-drop)** (`status-transition` EF) | ✅ |
| Admin menü görünürlüğü (ComingSoon fallback) | ✅ |
| Org/tenant seçim fix (null-active, gerçek plan) | ✅ |
| Push (FCM/APNs kayıt) | ✅ ~78 (deep-link KALAN) |
| i18n (DB keywords, 4 dil) | ✅ ~75 (yeni-key seed KALAN) |
| Offline (Hive kuyruk çerçevesi) | ◐ ~65 (per-service replay KALAN) |

---

## Faz 1 — Çekirdek UX'i tamamla (yakın vade, yüksek değer)

**Hedef:** kabuğun eksik "her-app" parçalarını bitir; web'deki yönetim erişimlerini yüzeye çıkar.

1. **Tenant + Organizasyon switcher'ları yüzeye çıkar.** Bugün org-seçim yalnız Ayarlar içinden; tenant-seçim (`tenant_selector_screen`) var ama görünür değil.
   - *Yap:* profil-hub'a ve/veya üst-bar'a "Organizasyon değiştir" + "Tenant değiştir" hızlı-erişim; platform-switcher ile aynı desende bir sheet.
   - *Mobil:* `main_shell` üst-bar / `profile_hub_screen`; `TenantService.setTenant`, `OrganizationService`.
2. **Dinamik alt-nav (kullanıcı/DB-seçimli).** `main_shell._dests` zaten config-liste — DB veya kullanıcı-tercihiyle sekmeleri seçilebilir yap.
   - *Backend:* kullanıcı-tercihi (local pref) veya `platform_menu_items` "bottom-eligible" flag.
3. **Gerçek admin ekranları** (ComingSoon → fonksiyonel). Öncelik sırası (veri erişilebilir):
   1. `/admin/user-management` (kullanıcı listesi/rol)
   2. `/admin/roles` · `/admin/rbac` (RBAC — `PtbRbacService` karşılığı)
   3. `/admin/org-chart` · `/admin/staff-roster` · `/admin/departments`
   4. `/admin/notifications-hub` · `/admin/bug-reports`
   - *Mobil:* `screen_resolver`'a gerçek resolver + yeni ekranlar; ağır builder'lar (`page-builder`, `workflow-designer`, `menu-builder`) ComingSoon kalır.
4. **Bildirim deep-link.** Push tap → ilgili ekrana yönlendirme.
   - *Mobil:* `push_notification_service.onNotificationTap` + router.

---

## Faz 2 — ESS derinliği (PHR)

**Hedef:** web ESS yüzeyinin kalanını taşı.

1. **Performans self-service** (hedefler/değerlendirmeler) — TAMAMEN eksik. Web `performance.routes.ts` (my-goals, my-reviews, review-queue).
   - *Mobil:* `hr_ess_service` + `example_phr` ekranları.
2. **Bordro PDF görüntüle/indir.** `myPayslips` yalnız satır döner; belge yok.
   - *Mobil:* `hr_ess_service` + `file_storage_service` (signed-URL).
3. **Onboarding görev tamamlama (yazma).** Bugün salt-okuma.
   - *Mobil:* `hr_ess_service.myOnboardingTasks` → complete/decision RPC.
4. **İzin onay-kararı.** `fn_hr_pending_leave_approvals` **approvalId döndürmüyor** (backend boşluk) → decide bağlanamıyor.
   - *Backend:* RPC'ye `approval_step_id` ekle; *mobil:* `decideLeave` (approval-decision EF) zaten hazır.
5. **Hesap güvenlik sekmesi** (MFA/TOTP + aktif oturumlar). Bugün yalnız biometrik.

---

## Faz 3 — Dinamik motor paritesi (web'in tüm dinamik gücü)

1. **Dashboard kişiselleştirme** (widget ekle/yapılandır). Bugün salt-render (`dyn_widgets`).
2. **Rapor export / drill-down.** Viewer salt-görüntü (`report_viewer`).
3. **Generic workflow/onay kutusu.** Bugün yalnız izin-onayı bağlı; web `WorkflowApprovalsComponent` (`/workflow/approvals`) generic.
   - *Mobil:* `workflow_service` + yeni onay-inbox ekranı.
4. **Page-viewer / form-viewer** etkileşim derinliği.

---

## Faz 4 — Drag-drop paketi (Kanban'ın ötesi)

**Web DnD envanteri** (hepsi `@angular/cdk/drag-drop`):

| Web özelliği | Ne sürüklenir | Backend |
|---|---|---|
| Entity/ticket **Kanban** ✅ | kart ↔ status kolonu | `status-transition` EF → `form_submissions.status` |
| **Backlog / scrum** | issue satırı sırala | `form_submissions.sort_order` / `backlog_rank` (`rerankBatch`) |
| **ATS pipeline** | aday ↔ stage | applications.stage |
| **Menu builder** | menü satırı sırala | `platform_menu_items.sort_order` |
| Page/form/report builder | widget/field (canvas) | tanım JSON — **ağır, ComingSoon** |

**Sıra:** (1) Backlog reorder — `ReorderableListView` + batch `sort_order`. (2) ATS pipeline. (3) Menu builder reorder (admin). Görsel builder'lar mobilde ertelenir.

**Not (Kanban çalışması için):** status geçişleri `status_transitions` tablosundan gelir (koda göre, tenant veya global `00000000-…`). Bir entity tipinin kanban'ı ancak geçiş-kuralları tanımlıysa kart taşır (web'i de gate'ler). Örn. `hr_expense` global iş-akışı bu oturumda seed'lendi (open→submitted→approved/rejected→completed→reimbursed).

---

## Faz 5 — Admin/console + ESS-dışı domainler (ayrı ince app'ler)

- Tam admin/console: user-mgmt, RBAC editleme, integrations, billing/subscription.
- ESS-dışı domainler paylaşılan-core üzerinde ince-app olarak: **PMS** monitoring derinliği (supervisor/KPI dashboard — RPC'ler var, ekran yok), **CRM**, **PPM**, marketplace, mail-system.

---

## Faz 6 — Enabler'lar (çok-platform üretim)

- **Offline write-queue** per-service replay handler'ları.
- **Push deep-link** yönlendirme.
- **i18n** yeni-key DB seed (eklenen key'ler ham-key'e düşüyor).
- **Mobil CI/CD + test** (entity-motor + menü-resolver + shell regresyon).

---

## Yöntem / ilkeler

1. **Her dinamik motor core'da** yaşar; ince-app'ler yalnız domain-resolver + marka/tema kaydeder (`ScreenResolver.addResolver`).
2. **Backend sözleşmesi web ile birebir** — aynı EF/RPC, ayrı config yok. Yeni bir yüzey eklerken önce web servisini + EF'i oku, gövde/yanıt şeklini birebir taşı.
3. **Paralel-ajanlar** bağımsız ekranlar için; paylaşılan dosyalar (barrel, service_locator, main_shell) tek elden montajlanır.
4. **Her faz simülatörde canlı-doğrulanır** (`scripts/sim`), 0-hata gate (`flutter analyze`).
5. **Layout tuzağı:** scroll-view içinde sınırsız-yükseklik Flex/`Row(stretch)` → geçersiz constraint + boş ekran; `IntrinsicHeight`/bounded-width/`shrinkWrap` şart.

---

## En yüksek-değer ilk 10 boşluk (öncelikli)

1. Generic workflow/onay inbox
2. Tenant/Org switcher yüzeye çıkarma (Faz 1.1)
3. Admin: user-management + RBAC ekranları
4. ESS performans self-service
5. Bordro PDF
6. Dashboard kişiselleştirme
7. Rapor export/drill-down
8. Onboarding görev-tamamlama (yazma)
9. İzin onay-kararı (backend approvalId)
10. Push deep-link + i18n key seed
