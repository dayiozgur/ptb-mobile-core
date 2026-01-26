/// Protoolbag Mobile Core Library
///
/// Enterprise-grade Flutter SaaS foundation library for Protoolbag ecosystem.
/// Provides multi-tenant architecture, Apple HIG compliant UI components,
/// and core services.
library protoolbag_core;

// Core - Theme
export 'src/core/theme/app_colors.dart';
export 'src/core/theme/app_typography.dart';
export 'src/core/theme/app_spacing.dart';
export 'src/core/theme/app_shadows.dart';
export 'src/core/theme/app_theme.dart';
export 'src/core/theme/theme_service.dart';

// Core - Utils
export 'src/core/utils/validators.dart';
export 'src/core/utils/formatters.dart';
export 'src/core/utils/logger.dart';

// Core - Extensions
export 'src/core/extensions/context_extensions.dart';
export 'src/core/extensions/string_extensions.dart';
export 'src/core/extensions/date_extensions.dart';

// Core - Errors
export 'src/core/errors/failures.dart';
export 'src/core/errors/exceptions.dart';

// Core - Storage
export 'src/core/storage/secure_storage.dart';
export 'src/core/storage/cache_manager.dart';

// Core - API
export 'src/core/api/api_client.dart';
export 'src/core/api/api_response.dart';
export 'src/core/api/interceptors/auth_interceptor.dart';
export 'src/core/api/interceptors/tenant_interceptor.dart';
export 'src/core/api/interceptors/logger_interceptor.dart';

// Core - Auth
export 'src/core/auth/auth_service.dart';
export 'src/core/auth/auth_result.dart';
export 'src/core/auth/biometric_auth.dart';

// Core - Tenant
export 'src/core/tenant/tenant_model.dart';
export 'src/core/tenant/tenant_service.dart';

// Core - Organization
export 'src/core/organization/organization_model.dart';
export 'src/core/organization/organization_service.dart';

// Core - Site
export 'src/core/site/site_model.dart';
export 'src/core/site/site_service.dart';

// Core - Unit
export 'src/core/unit/unit_model.dart';
export 'src/core/unit/unit_service.dart';

// Core - Invitation
export 'src/core/invitation/invitation_model.dart';
export 'src/core/invitation/invitation_service.dart';

// Core - Permission
export 'src/core/permission/permission_model.dart';
export 'src/core/permission/permission_service.dart';

// Core - Activity
export 'src/core/activity/activity_model.dart';
export 'src/core/activity/activity_service.dart';

// Core - Notification
export 'src/core/notification/notification_model.dart';
export 'src/core/notification/notification_service.dart';

// Core - Connectivity (Offline Support)
export 'src/core/connectivity/connectivity_service.dart';
export 'src/core/connectivity/offline_sync_service.dart';

// Core - Reporting (Analytics)
export 'src/core/reporting/reporting_model.dart';
export 'src/core/reporting/reporting_service.dart';

// Core - Search
export 'src/core/search/search_model.dart';
export 'src/core/search/search_service.dart';

// Core - Localization
export 'src/core/localization/localization_service.dart';
export 'src/core/localization/app_localizations.dart';

// Core - DI & Initialization
export 'src/core/di/service_locator.dart';
export 'src/core/di/core_initializer.dart';

// Presentation - Widgets - Buttons
export 'src/presentation/widgets/buttons/app_button.dart';
export 'src/presentation/widgets/buttons/app_icon_button.dart';

// Presentation - Widgets - Inputs
export 'src/presentation/widgets/inputs/app_text_field.dart';
export 'src/presentation/widgets/inputs/app_dropdown.dart';
export 'src/presentation/widgets/inputs/app_date_picker.dart';
export 'src/presentation/widgets/inputs/app_search_bar.dart';

// Presentation - Widgets - Cards
export 'src/presentation/widgets/cards/app_card.dart';
export 'src/presentation/widgets/cards/metric_card.dart';

// Presentation - Widgets - Lists
export 'src/presentation/widgets/lists/app_list_tile.dart';
export 'src/presentation/widgets/lists/app_section_header.dart';

// Presentation - Widgets - Navigation
export 'src/presentation/widgets/navigation/app_scaffold.dart';
export 'src/presentation/widgets/navigation/app_tab_bar.dart';
export 'src/presentation/widgets/navigation/app_bottom_sheet.dart';

// Presentation - Widgets - Feedback
export 'src/presentation/widgets/feedback/app_loading_indicator.dart';
export 'src/presentation/widgets/feedback/app_error_view.dart';
export 'src/presentation/widgets/feedback/app_empty_state.dart';
export 'src/presentation/widgets/feedback/app_badge.dart';
export 'src/presentation/widgets/feedback/app_snackbar.dart';
export 'src/presentation/widgets/feedback/notification_badge.dart';
export 'src/presentation/widgets/feedback/offline_indicator.dart';

// Presentation - Widgets - Display
export 'src/presentation/widgets/display/app_avatar.dart';
export 'src/presentation/widgets/display/app_progress_bar.dart';
export 'src/presentation/widgets/display/app_chip.dart';
