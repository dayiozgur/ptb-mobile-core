# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Proposed version: **`protoolbag_core` 1.4.0** (minor: new public API; two
source-incompatible signatures are listed under *Changed*). The six apps stay
at marketing version `1.0.0`; their build number is raised per store upload
(`./scripts/build-testflight.sh <app> <issuer> <build>` /
`./scripts/build-release-android.sh <app> <build>`). Nothing below has been
released; `pubspec.yaml` versions are unchanged until the owner cuts the
release.

### Security
- **Second factor for administrators, as on the web (2026-11-14).** `MfaGate`
  reads `fn_my_mfa_requirement()` (new `AuthService.getMyMfaRequirement`,
  `MfaRequirement`) instead of only the tenant's `mfa_policy`: platform
  operators and active rbac `admin` / `super_admin` holders always need a
  second factor; a tenant policy can widen it to every member. Outcomes:
  enrolment / authenticator code / mailed code / none. When the requirement
  cannot be read, an administrator (server says privileged, or local coarse
  role `ROLE_ADMIN`) gets the new `MfaStepUp.unavailable` retry / sign-out
  state; everyone else fails open (web parity). An unknown AAL is challenged
  for administrators. The gate is also evaluated on cold start with a
  restored session (closing the app on the second-factor screen no longer
  skips it). Live data 2026-11-14: no tenant has an `mfa_policy`; 6 active
  privileged accounts — 5 will be asked for their code at the next mobile
  sign-in, 1 must enrol.
- **Self-service password change verifies the current password (CRA F-108).**
  `AuthService.changePasswordVerified` checks the current password with a
  throwaway, stateless GoTrue password-grant call (nothing persisted, no auth
  events, the throwaway session is revoked with `logout?scope=local`), then
  calls `updateUser(password, current_password)` on the main client. Wrong
  password, rate limit and network failures are distinct outcomes. Used by the
  Security screen, the Settings screen (all six apps) and the demo app;
  `changePassword` (unverified) is deprecated, `updatePassword` remains for
  invite / recovery links only.
- **Accounts with an authenticator (TOTP).** GoTrue refuses a password change
  from an AAL1 session when MFA is enabled (`insufficient_aal`). The sheet now
  asks for the 6-digit code and repeats the change after confirming it on the
  main session (`mfaCode`); a wrong code is shown on the code field and nothing
  is changed. "Secure password change" (`reauthentication_needed`) shows the
  same "sign out and sign in again" text as the web app instead of a generic
  failure.
- **Microsoft disconnect goes through the `integration-disconnect` Edge
  Function** (Graph subscriptions, Vault secret, audit row) instead of a direct
  row delete (F-138).
- **Special-category staff columns are no longer selected from `staffs`**
  (`address`; KVKK md.6, S-06) — the queries failed with 42501 after the column
  grant was revoked. A scan test guards every `staffs` select.

### Added
- Settings → **Delete my account** (all six apps): two-sentence explanation,
  then the app's public page `https://app.<code>.protoolbag.com/legal/account-deletion`
  in the browser. Independent of the server endpoint (2026-11-14).
- `RelativeTime` (`past` / `future` / `of` / `duration`) from `time.*`
  keywords; `AppLocale.intlLocale` (tr_TR / en_GB / de_DE / it_IT).
- `MfaRequirement`, `MfaGateBackend`, `MfaGate.retry`, `MfaStepUp.unavailable`.
- PHR, PMS and PPM register their OAuth return schemes (`ptbphr`, `ptbpms`,
  `ptbppm`) with an OAuth-only link listener — Microsoft can be connected
  from these apps (server already accepts the schemes).
- Tests: a ratchet against new hard-coded Turkish literals in
  `lib/src/presentation` (`test/lint/`), and a contract test that every
  `appUrlScheme` is registered on Android and iOS and allowed by the server.
- `GraphProblem` / `GraphProblemKind`: classified Microsoft Graph failures (not
  connected, reconnect, missing consent, administrator approval required,
  forbidden, throttled with retry-after, not found, conflict, blocked,
  unavailable, failed) and `MsProblemView`, the honest state shown instead of an
  empty list on mail, files, calendar, people, Teams and Planner.
- `OAuthReturnNotice` / `MicrosoftOAuthReturn`: the connect flow's
  `oauth_error` / `admin_consent` deep-link results, one translated message per
  value.
- `AccessErrors`, `AppNoAccessView`, `AppLoadFailedView`: "no access" (42501 /
  403) is a calm state, a failed load is never the empty state. `AsyncView`
  uses them.
- `InAppRoute.webOrigin` / `webUrlFor` and the web-only wording of
  `ComingSoonScreen` with **Open on the web**; `ScreenResolver.canOpen`,
  `isWebOnly`, `webOnlyScreen`.
- `WorkflowService.pendingApprovalsOrThrow`, `WorkInboxService.loadOrThrow`,
  `MicrosoftIntegrationService.lookupConnection`.

### Changed
- **Behaviour change — list reads rethrow instead of returning an empty list
  (2026-11-14):** `NotificationService.getNotifications`,
  `CommentsService.list`, `CrmActionsService.listSequences`,
  `AlarmService.getHistory` / `getResetAlarms` / `getTopAlarms`,
  `IoTLogService.getLogs` / `getLogTimeSeries` / `getLogsByTimeRange`,
  `SiteService.getSites`, `UnitService.getUnits`,
  `OrganizationService.getOrganizations`, `MapService.getSiteMarkers`,
  `AnnouncementService.list`, `SprintService.listSprints`,
  `WorklogService.listWorklogs`, `SearchService.globalSearch`,
  `EntityFileLinkService.list`, `FileStorageService.listEntityFiles`; CRM
  `ContactsService.list` / `activityFeed`. Every caller in the six apps and the
  demo app handles the error.
- Dates and numbers follow the UI language: `LocalizationService` sets
  `Intl.defaultLocale`; `Formatters` / `DateTime` extension / dynamic widget /
  PHR ESS formatting no longer default to `tr_TR` (`locale` parameters are
  nullable). Date symbols for all four languages load at start.
- `MfaGate.evaluate`'s `tenantId` is optional and unused.
- `translate()` replaces web-style `{{name}}` placeholders (and `{name}`).
- **Source-incompatible:** `MicrosoftIntegrationService.graphCall` returns a
  non-null `GraphResult` (a failure carries `problem`; it used to return
  `null`). `PlannerLinkService.listPlans` returns `PlannerPlansResult`.
- `HrEssService.myGoals` / `myReviews` rethrow read errors (their screens show
  "could not load" instead of "no goals / no reviews").
- `/report/my` is the personal report builder, not a report code; `/m365/mail`
  opens the core mailbox by link but is not a mobile menu entry; the PEM setup
  wizard is hidden on mobile.
- Approvals inbox, placeholder screen and the error view's retry label use
  keywords instead of hardcoded Turkish text.

### Fixed
- **Errors rendered as empty lists (2026-11-14):** a failed read now shows a
  retry state, a refused read (42501 / 403) the calm no-access state, and an
  RLS-filtered empty result stays the normal empty state, on: notifications
  inbox; CRM contacts list, contact activity feed, enrol-in-sequence sheet;
  shared comments thread; PMS site and provider pages (per section:
  providers, controllers, alarm history, logs, top alarms; KPI shows '—'),
  controller recent logs, variable / analytics / provider charts, alarm
  history, global alarms, alarm dashboard, log viewer, sites list and
  selector, site map, monitoring dashboard site count; organisation selector;
  PPM sprint management and work-log history; global search; announcements;
  the files card; the platform switcher. Kept fail-soft on purpose: badge
  counts (notification unread count / summary, site alarm counts), lookups
  (site types / groups, unit types), comment author names, search
  suggestions, demo-only `SearchService.search`. 73 swallow-to-empty
  `catch` blocks remain by the same pattern search (98 before).
- Approvals inbox and work inbox showed "nothing pending" / "no assigned work"
  when the load failed.
- PMS Site and provider screens showed a green "0 active alarms" when the alarm
  read failed.
- PEM alarm priorities and unit types with `active IS NULL` were hidden.
- An https app link to a page without a mobile screen was a silent no-op.

### Store preparation (configuration and documents — nothing built, signed or submitted)
- `docs/store/STORE-READINESS-2026-11.md`: per-app readiness table, blockers,
  privacy answers for both stores, owner checklists, release order;
  `docs/store/listings/` (tr / en listing drafts) and `docs/store/well-known/`
  (`assetlinks.json` / `apple-app-site-association` templates).
- iOS: permission purpose strings in English and Turkish (`InfoPlist.strings`)
  with the missing keys added (location: CRM, PPM, PEM; camera and photos:
  PEM); PEM privacy manifest added; precise location declared in the CRM, PPM,
  FixFlow and PEM manifests; PMS display name "Protoolbag PMS".
- Android: launcher labels are the product names; foreground location
  permission declared (no location request could succeed before);
  `MainActivity` is a `FlutterFragmentActivity` (required for biometric
  sign-in); launcher icons use each app's brand icon instead of the template
  default.
- Settings: privacy policy and terms of service links (public web pages), the
  installed version instead of a hardcoded one.
- Release scripts accept FixFlow (and PEM on Android).

### Keywords
18 new keys (tr / en / de / it) are proposed in
`docs/proposed-sql/20261113_mobile_store_prep_keywords.sql` and 118 more in
`docs/proposed-sql/20261114_mobile_followups_keywords.sql` (124 keys used; 6
already exist live) — not applied; the apps fall back to the built-in tr / en
/ de texts until then (Italian → English).

### Planned for Phase 3
- Controller/Provider/Variable models (IoT layer)
- Workflow management system
- Calendar and events module
- Inventory management module

## [1.3.0] - 2026-08-20

### Changed - Backend modernization (align to hardened web backend)
Bringing the mobile core to the current web maturity — the platform-as-OS
model, modern RBAC/access, and one-round-trip Supabase connections. See
`docs/MOBILE_MODERNIZATION_ROADMAP.md`.

- **M0 — RBAC + cold-start + profile model:**
  - `UserProfile` realigned to the live `profiles` schema (`full_name`, `active`,
    `last_login`, `site_id`, `tenant_id`); stopped mapping/writing ~19 dropped
    columns (display_name, status, gender, organization_id, …).
  - One-round-trip cold-start via `fn_my_profile_bundle()`
    (`ProfileService.getProfileBundle`), with timeout + retry + fallback.
  - Coarse-role RBAC via `fn_my_coarse_role`/`fn_coarse_role_of`
    (ROLE_ADMIN/MANAGER/USER/CUSTOMER); removed dead `roles`/`role_permissions`/
    `tenant_users.role` lookups.
  - Avatar signed-URL aligned to web (`platform-protected` bucket + `isStoragePath`).
- **M2 — Backend RPC adoption (perf + drift-loud):**
  - `AlarmService` now uses `fn_pms_kpi_summary`/`_alarm_trend`/
    `_alarm_priority_breakdown`/`_alarm_site_controller` + ack/reset/inhibit RPCs
    instead of client-side aggregation (tenant-scope-guarded).
  - `IotLogService` uses `fn_controller_logged_variables` instead of scanning the
    1.97M-row `logs` fact table for variable enumeration.
  - Fixed the `NotificationService` realtime channel leak (removeChannel).
  - Silent error-swallows surfaced (drift becomes loud, not a blank dashboard).
- **M1 — DB-driven menu + platform switch + coarse-role route guard:**
  `MobileMenuService` loads `platform_menu_items` (role-filtered, nested tree) →
  dynamic bottom-nav + drawer; `fn_my_platform_catalog` platform switcher;
  `bi-*`→Material icon map; web-path→mobile-screen resolver (unbuilt→ComingSoon);
  go_router coarse-role guard (CUSTOMER→portal).
- **M3 — invite-only + onboarding:** killed open self-service signup (→
  `access_requests` waitlist); `InvitationService` now uses `tenant_users` +
  the `invite-user` Edge Function (removed the nonexistent `tenant_invitations`);
  accept-invite deep-link via `verifyOtp(OtpType.invite)` → strong-password set.
- **M4 — i18n from DB keywords:** `LocalizationService` DB-backed from `keywords`
  (paginated, 1h cache), resolution DB→static→key (no silent drift, no crash);
  49 shared-widget literals + 38 M1/M3 keys routed through `translate()`.

Integration-verified: `dart analyze` reports 0 errors / 0 warnings in both
`lib/` and `example_pms/lib/`. Owner follow-ups: native deep-link registration,
DB-seeding the new i18n keys, on-device smoke.

## [1.2.0] - 2026-01-26

### Added - Phase 2 Features
- **Push Notification Service** (`push_notification_service.dart`)
  - FCM and APNs token management
  - Notification permissions handling
  - Topic subscription support
  - Notification channels (iOS 10+, Android O+)
  - Background/foreground message handling

- **Realtime Service** (`realtime_service.dart`)
  - Supabase Realtime integration
  - Database change subscriptions (INSERT, UPDATE, DELETE)
  - Presence tracking for user status
  - Broadcast messaging for real-time communication
  - Typed generic change handlers

- **File Storage Service** (`file_storage_service.dart`)
  - Supabase Storage integration
  - File upload with progress tracking
  - File download and URL generation
  - Image compression and thumbnails
  - MIME type detection
  - Multiple bucket support

- **Pagination Helpers** (`pagination.dart`)
  - PaginatedList<T> with status management
  - PaginationController for automatic loading
  - Cursor-based pagination support
  - Supabase range helpers
  - Infinite scroll support

- **Error Boundary Widget** (`error_boundary.dart`)
  - Global error catching
  - Fallback UI rendering
  - Error reporting hooks
  - runAppWithErrorHandler for app-wide protection

### Changed
- Improved service locator with new service registrations
- Enhanced protoolbag_core.dart exports

## [1.1.0] - 2026-01-26

### Added - Phase 1 Features
- **Localization Service** (`localization_service.dart`)
  - Multi-language support (TR, EN, DE)
  - Locale persistence with SecureStorage
  - Number, currency, date formatters
  - Interpolation support in translations
  - Hot-reload locale switching

- **Comprehensive Unit Tests**
  - `test/services/localization_service_test.dart`
  - `test/services/theme_service_test.dart`
  - `test/services/connectivity_service_test.dart`
  - `test/services/offline_sync_service_test.dart`
  - `test/models/notification_model_test.dart`
  - `test/models/search_model_test.dart`
  - `test/models/reporting_model_test.dart`

- **Integration Tests**
  - `test/integration/service_integration_test.dart`
  - `test/integration/widget_integration_test.dart`

- **Database Migrations**
  - `001_rls_policies.sql` - Row Level Security policies
  - `002_schema_improvements.sql` - Schema improvements and indexes

- **Database Documentation**
  - `DATABASE_SYNC_PLAN.md` - Comprehensive sync plan

### Fixed
- SecureStorage write method signature (named parameters)
- AppColors method calls for brightness-aware colors
- NotificationEntityType switch exhaustiveness
- Nullable title handling in notifications

## [1.0.0] - 2024-01-26

### Added
- Complete authentication flow with email/password
- Social login (Google, Apple)
- Biometric authentication (Face ID, Touch ID)
- Multi-tenant architecture
- 30+ production-ready UI components
- Theme system with light/dark mode
- API client with interceptors
- Secure storage for sensitive data
- Cache management with TTL
- Form validators and formatters
- Navigation and routing utilities
- Error handling framework
- Logging system
- Example application

### Components Added
- AppButton with 4 variants
- AppTextField with validation
- AppCard with gestures
- AppListTile iOS-style
- AppBottomSheet modal
- AppScaffold with navigation
- AppLoadingIndicator
- AppErrorView
- AppEmptyState
- AppBadge
- AppAvatar
- AppProgressBar
- AppChip
- MetricCard

### Services Added
- AuthService
- ApiClient
- TenantService
- StorageService
- CacheManager
- BiometricAuth
- Logger

### Documentation
- Complete README
- Architecture guide
- Design system documentation
- API reference
- Component library catalog
- Development guide
- Best practices
- Migration guides
- Code examples
- Contributing guidelines

## [0.9.0] - 2024-01-15 [BETA]

### Added
- Dark mode support
- Offline-first data sync
- Real-time updates with Supabase
- Pagination helpers
- Image caching
- Pull-to-refresh

### Changed
- Improved error messages
- Better loading states
- Enhanced form validation

### Fixed
- Memory leaks in stream subscriptions
- BuildContext usage after async
- Token refresh issues

## [0.8.0] - 2024-01-01 [ALPHA]

### Added
- Initial alpha release
- Basic authentication
- Simple UI components
- API integration
- Local storage

---

## Version History

- **1.0.0** (2024-01-26) - First stable release
- **0.9.0** (2024-01-15) - Beta release
- **0.8.0** (2024-01-01) - Alpha release

## Upgrade Guide

For upgrade instructions between versions, see [MIGRATION_GUIDE.md](docs/MIGRATION_GUIDE.md).
```

# 📄 LICENSE
```
MIT License

Copyright (c) 2024 Protoolbag

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.