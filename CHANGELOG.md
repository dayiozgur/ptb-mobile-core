# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned for Phase 3
- Controller/Provider/Variable models (IoT layer)
- Workflow management system
- Calendar and events module
- Inventory management module

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