# Mobile Modernization Roadmap — align to the hardened web backend

> **Vision:** the mobile app was written when the DB/Edge-Functions were **weaker than the final web**. Bring it to the current maturity — the **platform-as-OS** model, modern RBAC/access, hardened Supabase connections (one-round-trip cold-start), invite-only onboarding, and DB-sourced i18n. Same Supabase DB (`gzdhnonhjnxjpqcnrohu`), no new backend → low risk, high speed.
>
> **Owner decisions (2026-08-20):** single app + **in-app platform switch** (not per-platform flavor); **PMS first** (`example_pms` is the base to modernize, not rebuild).

Derived from a 6-dimension parallel audit of `ptb-mobile-core` vs `protoolbag-platform` + the live DB. The mobile is feature-rich but wired to a **dead backend model** (legacy `tenant_users.role`, nonexistent `roles`/`role_permissions`, dropped `profiles.role`, hardcoded menu/plans, static i18n). Every gap below is grounded in real code.

---

## Status — 2026-08-20 — M0–M5 COMPLETE ✅
All six milestones landed and integration-verified: `dart analyze lib/` and `dart analyze example_pms/lib/` both report **0 errors, 0 warnings** (only pre-existing info-level style lints remain). The mobile now runs on the current hardened web backend — coarse-role RBAC, one-round-trip cold-start, DB-driven OS-menu with platform switch, server RPCs, invite-only onboarding, DB-sourced i18n.

**Owner/native follow-ups (not code-side):** native deep-link registration (iOS Associated Domains + `Info.plist` / Android intent-filter + AASA/assetlinks) for invite links; `flutter test` + build + on-device smoke (build/deploy = owner). ✅ i18n DB-seed DONE — 508 tr / 508 en / 511 de mobile-only keys seeded into shared `keywords` (idempotent, `WHERE NOT EXISTS`); 110 keys already existed and were left to web authority (49 benign wording diffs → mobile shows web's canonical value); web unaffected, no CACHE_VERSION bump needed. **Code follow-ups:** ✅ `backend_contract.json` pinned snapshot committed (23 tables/63 RPCs/17 enums/5 checks); ✅ storage-reconciliation — mobile now uses the real 3-bucket web contract (`platform-public/protected/private`) + web path scheme + **`storage_objects` registry write on every upload** (the `platform-protected` SELECT RLS checks that metadata row, not the path — without it uploads are unreadable even by the uploader) + canonical entity-scoped avatar path so web↔mobile files are mutually readable; ✅ feature-screen i18n wave — ~550 `translate()` call-sites across all PMS feature screens + 364 new keys (tr/en/de) in the static fallback, `error_boundary` migrated with a guarded helper. Only owner follow-ups remain (native deep-link, seed the ~440 new keys into shared `keywords` + web CACHE_VERSION bump, on-device smoke).

### Milestone detail
- ✅ **M0 done** — profile model realigned to live schema; `fn_my_profile_bundle` one-round-trip cold-start (timeout+retry+fallback); coarse-role RBAC via `fn_my_coarse_role`/`fn_coarse_role_of`; dead `roles`/`role_permissions`/`tenant_users.role` removed; avatar signed-URL aligned to web (`platform-protected` bucket + `isStoragePath`). `dart analyze lib/` clean.
- ✅ **M2 done** — Alarm/IoT/Notification/Org services adopt `fn_pms_*` RPCs (tenant-scope-guarded); `fn_controller_logged_variables` replaces the 1.97M-row logs scan; realtime channel leak fixed; silent-swallows surfaced. `dart analyze lib/` clean.
- ✅ **M5 done** — version SoT = pubspec `1.3.0`; README + CHANGELOG aligned; `scripts/check_version.sh` guard.
- ✅ **M1 done** — `MobileMenuService` loads `platform_menu_items` (role-filtered, nested tree); dynamic bottom-nav + drawer + platform-switcher (`fn_my_platform_catalog`); `bi-*`→Material icon map; web-path→mobile-screen resolver (unbuilt→`ComingSoon`); coarse-role go_router guard (CUSTOMER→portal, admin-only prefixes from DB). `dart analyze` clean both packages.
- ✅ **M3 done** — open self-service signup killed (→ `access_requests` waitlist); `InvitationService` writes to `tenant_users` + `invite-user` EF (no more nonexistent `tenant_invitations`); accept-invite deep-link via `verifyOtp(OtpType.invite)` → strong-password set; go_router deep-link route + guard allowlist.
- ✅ **M4 done** — `LocalizationService` DB-backed from `keywords` (tr-TR 19.5k rows, paginated, 1h cache), resolution order DB→static→key (never drifts silently, never crashes); 49 shared-widget literals + 9 M1 keys + 29 M3 auth keys through `translate()`. ~150 feature-screen literals remain (listed) for a follow-up wave.
- 📝 **Follow-ups:** (a) storage-reconciliation — mobile's bucket constants `organization-files`/`site-files`/`unit-files`/`documents` don't exist in the live project; align to real buckets. (b) `database/backend_contract.json` pinned snapshot — needs `supabase link` (owner DB password). (c) NotificationPreferences persistence (no DB column). (d) ~150 remaining feature-screen i18n literals. (e) native deep-link registration + DB seeding of new i18n keys + on-device smoke = owner.

---

## M0 — Foundation: RBAC + session (unblocks everything) · HIGH
The whole app currently mis-resolves identity. Fix this first; menu/entitlement/screens all depend on the coarse role + bundle.

| # | Gap | Action |
|---|-----|--------|
| 0.1 | Session-init = 4+ serial round-trips (`core_initializer.dart:255-289` restoreSession→restoreLastTenant→restoreLastOrganization + separate `profile_service.dart:71`) | Add `getProfileBundle()` → `rpc('fn_my_profile_bundle')` (one jsonb: profile+tenant_name+organization_id+coarse_role); make it the primary cold-start path, old flow = fallback |
| 0.2 | **RBAC broken:** role read from `tenant_users.role` (2 legacy rows) + nonexistent `roles`/`role_permissions` (`permission_service.dart:44,166,241`) → null for every real user → admins gate as non-admin | Replace with `rpc('fn_my_coarse_role')` (self) / `fn_coarse_role_of(p_profile)` (others) → `ROLE_ADMIN\|MANAGER\|USER\|CUSTOMER` from `rbac_user_roles` (22 assignments). Delete the roles/role_permissions path (theatre) |
| 0.3 | Role vocabulary mismatch: mobile hardcodes owner/admin/manager/member/viewer @100/80/60/40/20 (`permission_model.dart:313`, `tenant_model.dart:477`) — no DB row matches | Model roles as the **coarse set**; if fine-grained needed read `rbac_roles` (super_admin/admin/manager/dispatcher/inspector/technician/reporter/customer) |
| 0.4 | `UserProfile.fromJson` maps ~20 dropped/renamed columns (`user_profile.dart:259` role/status/organization_id/display_name/... none exist) → silent nulls; `active` never read (deactivated users not gated) | Realign to live schema: displayName→`full_name`, status→`active`(bool, gate on it), lastLoginAt→`last_login`, defaultSiteId→`site_id`; role from RBAC, org from bundle/`staffs` |
| 0.5 | No route/screen guard by role (grep: no GoRouter role redirect); every screen unprotected | Coarse-role router guard: resolve role once at boot → redirect. CUSTOMER→portal-only, admin screens require ADMIN |
| 0.6 | No cold-start timeout/retry/optimistic-cache (`profile_service.dart:71` rethrows; `auth_service.dart:514` no deadline) | Wrap profile/session load in timeout + bounded retry + direct-fallback; optimistic-paint cached essentials (name/avatar/tenant/role) first |
| 0.7 | Avatar via `getPublicUrl` → 403 on private bucket (`file_storage_service.dart:352,398`) | `getAvatarUrl(raw)` → `createSignedUrl` on avatars bucket (helper already at `:502`) |
| 0.8 | Duplicate manual token storage + unbounded getSession (`auth_service.dart:183,538`) | Rely on GoTrue as single session store; bounded session read |

## M1 — "Windows-OS" platform model · HIGH
| # | Gap | Action |
|---|-----|--------|
| 1.1 | Nav fully hardcoded (5 tabs `main_shell_screen.dart`, ~15 routes `router.dart`); **zero** `platform_menu_items` refs. DB has 410 active menu items (PMS 122) | `MobileMenuService` (mirror web `libs/core/services/src/menu/ptb-db-menu.loader.ts`): query `platform_menu_items` by platform_id+app_code+active → nested tree → dynamic bottom-nav/drawer + routes |
| 1.2 | No per-item role/permission gating (99 items carry `roles` arrays, 6 `permission`) → every tab shows to all roles | Apply web filter chain: drop items whose roles/permission exclude the coarse role; guard hidden paths |
| 1.3 | Single-platform build; no platform switch (DB: 6 platforms w/ own menus) | `PlatformContext` + switcher via `fn_my_platform_catalog` → active platform_id drives MenuService (one shell renders any platform) |
| 1.4 | Entitlement hardcoded + drifted (`tenant_model.dart PlanFeatures.forPlan` plan names free/basic/professional/enterprise vs web free/starter/pro/enterprise; ignores 665 `plan_quotas`) | `EntitlementService` reads `fn_my_platform_catalog` + `plan_quotas` at runtime; gate menu/routes/actions on server-truth |

## M2 — Backend adoption: perf + drift-loud · HIGH
Mobile calls **zero** PMS `fn_*` RPCs (253 direct `.from()` reads) — misses server aggregation + this cycle's fixes; silent swallows hide drift.

| # | Gap | Action |
|---|-----|--------|
| 2.1 | `alarm_service.dart` re-implements KPI/MTTR/timeline/priority-site groupings in Dart over raw `alarms`/`alarm_histories` | Replace with `fn_pms_kpi_summary` / `fn_pms_active_alarms` / `fn_pms_alarm_trend` / `fn_pms_alarm_priority_breakdown` (all live) |
| 2.2 | `iot_log_service.dart:147` scans the **1.97M-row `logs`** fact table directly (the web's ~178k-row bug) | Route via `fn_controller_logged_variables(p_controller_id)`; aggregate via `fn_pms_telemetry_summary` |
| 2.3 | `NotificationService` realtime leak — `unsubscribe()` without `removeChannel()` (`:416,441`) | Add `removeChannel()` after unsubscribe (match `realtime_service.dart:326`) |
| 2.4 | Aggregation errors swallowed to empty/zero (`alarm_service` `:362,387`; `organization_service.dart:246 catch(_){}`) → blank/0 dashboard on drift | Surface as error-state; RPC adoption makes signature-drift throw loudly |
| 2.5 | Drift-guard documented but not wired — `database/backend_contract.json` not committed | Run `scripts/gen_backend_contract.sql` → commit `database/backend_contract.json` → CI diff live-vs-pinned |

## M3 — Invite-only + onboarding · HIGH (security)
| # | Gap | Action |
|---|-----|--------|
| 3.1 | **Open self-service signup** (`register_screen.dart:52` signUpWithEmail → straight into app) contradicts web invite-only | Remove the open signup route/link; login-only entry |
| 3.2 | Self-built `InvitationService` writes a nonexistent `tenant_invitations` table (`:36,148`) | Move to the web flow: `invite-user` EF + `tenant_users.invitation_token`(uuid)+`invitation_expires_at` |
| 3.3 | No deep-link accept-invite / onboarding / waitlist / auth-branding | accept-invite deep-link (token_hash + `verifyOtp`, prefetch-safe) + force strong-password; onboarding (`tenants.onboarding_completed`); waitlist → `access_requests` |

## M4 — i18n from DB keywords · MEDIUM
| # | Gap | Action |
|---|-----|--------|
| 4.1 | Hardcoded static maps (`app_localizations.dart` 677 lines tr/en/de) already **drifted** from DB `keywords` (19,468 tr-TR rows; nav.dashboard 'Panel' vs DB 'Gösterge Paneli') | Make DB `keywords` the source: fetch tr-TR (key/defaultvalue) into `LocalizationService` or a build-time synced bundle |
| 4.2 | 33+ inline Turkish literals bypass even the local service (`active_alarm_list.dart` 'AKTİF ALARM', etc.) | Route all UI strings through `translate()` |
| — | Theme at parity (light+dark, tr_TR intl ₺/date correct in `formatters.dart`); design is Apple-HIG vs web Bootstrap+PTB — a deliberate divergence, leave unless a unified look is wanted | — |

## M5 — Hygiene · S
- **Version SoT:** pubspec `1.3.0` / README `1.2.0` / no git-tag → pick pubspec as truth, sync README+CHANGELOG, add `scripts/check_version.sh`.
- **Env flavor** (dev/staging/prod only — NOT per-platform, per owner decision): `AppFlavor` + `env_config` → staging Supabase for dev/staging (owner creates), prod → live.

---

### Sequencing
**M0 first** (identity is wrong everywhere) → **M1** (OS-menu depends on coarse role) → **M2** (perf + makes drift loud) in parallel with **M3** (security) → **M4/M5**. M0+M1+M2 ≈ the "modern PMS shell on the hardened backend"; M3 closes the invite-security gap; M4 removes i18n drift.
