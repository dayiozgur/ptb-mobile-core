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

// Core - Branding (DB-driven per-platform branding)
export 'src/core/branding/branding_config.dart';
export 'src/core/branding/branding_service.dart';

// Core - Utils
export 'src/core/utils/validators.dart';
export 'src/core/utils/formatters.dart';
export 'src/core/utils/logger.dart';
export 'src/core/utils/db_field_helpers.dart';

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
export 'src/core/storage/file_storage_service.dart';

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

// Core - User
export 'src/core/user/user_profile.dart';
export 'src/core/user/profile_service.dart';

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
export 'src/core/notification/local_notification_service.dart';
export 'src/core/time/app_clock.dart';
export 'src/core/collaboration/comments_service.dart';
export 'src/core/work/work_inbox_service.dart';
export 'src/core/ppm/worklog_service.dart';
export 'src/core/ppm/ppm_metrics.dart';
export 'src/core/crm/crm_actions_service.dart';
export 'src/presentation/shell/collaboration/comments_thread.dart';
export 'src/presentation/shell/work/work_inbox_screen.dart';
export 'src/presentation/shell/summary/summary_screen.dart';
export 'src/presentation/shell/summary/summary_cards.dart';
export 'src/core/notification/notification_model.dart';
export 'src/core/notification/notification_service.dart';

// Core - Connectivity (Offline Support)
export 'src/core/connectivity/connectivity_service.dart';
export 'src/core/connectivity/offline_sync_service.dart';
export 'src/core/connectivity/supabase_replay_dispatcher.dart';

// Core - Reporting (Analytics)
export 'src/core/reporting/reporting_model.dart';
export 'src/core/reporting/reporting_service.dart';
export 'src/core/reporting/report_query_service.dart';
export 'src/core/reporting/aggregate_service.dart';
export 'src/core/scan/card_scanner.dart';
export 'src/core/scan/document_scanner.dart';
export 'src/core/scan/ocr_models.dart';
export 'src/core/scan/receipt_parser.dart';
export 'src/core/utils/url_actions.dart';
export 'src/core/realtime/realtime_refresher.dart';
export 'src/core/reporting/report_service.dart';
export 'src/core/reporting/page_service.dart';

// Core - Search
export 'src/core/search/search_model.dart';
export 'src/core/search/search_service.dart';

// Core - Localization
export 'src/core/localization/localization_service.dart';
export 'src/core/localization/app_localizations.dart';
export 'src/core/localization/language_service.dart';

// Core - Push Notifications
export 'src/core/push/push_notification_service.dart';

// Core - Realtime
export 'src/core/realtime/realtime_service.dart';

// Core - Pagination
export 'src/core/pagination/pagination.dart';

// Core - Controller (IoT)
export 'src/core/controller/controller_model.dart';
export 'src/core/controller/controller_service.dart';

// Core - Provider (IoT)
export 'src/core/provider/provider_model.dart';
export 'src/core/provider/provider_service.dart';

// Core - Variable (IoT)
export 'src/core/variable/variable_model.dart';
export 'src/core/variable/variable_service.dart';

// Core - IoT Realtime (Controller-Variable Junction)
export 'src/core/iot_realtime/iot_realtime_model.dart';
export 'src/core/iot_realtime/iot_realtime_service.dart';

// Core - Workflow
export 'src/core/workflow/workflow_model.dart';
export 'src/core/workflow/workflow_service.dart';

// Core - Priority (Alarm Priorities)
export 'src/core/priority/priority_model.dart';
export 'src/core/priority/priority_service.dart';

// Core - Alarm (Active Alarms & History)
export 'src/core/alarm/alarm_model.dart';
export 'src/core/alarm/alarm_history_model.dart';
export 'src/core/alarm/alarm_service.dart';
export 'src/core/alarm/alarm_stats_model.dart';

// Core - IoT Log (Operational Logs)
export 'src/core/iot_log/iot_log_model.dart';
export 'src/core/iot_log/iot_log_service.dart';
export 'src/core/iot_log/iot_log_stats_model.dart';

// Core - Work Request (İş Talepleri)
export 'src/core/work_request/work_request_model.dart';
export 'src/core/work_request/work_request_service.dart';

// Core - Calendar (Takvim)
export 'src/core/calendar/calendar_event_model.dart';
export 'src/core/calendar/calendar_service.dart';

// Core - Todo
export 'src/core/todo/todo_model.dart';
export 'src/core/todo/todo_service.dart';

// Core - Staff
export 'src/core/staff/staff_model.dart';
export 'src/core/staff/staff_service.dart';

// Core - Team
export 'src/core/team/team_model.dart';
export 'src/core/team/team_service.dart';

// Core - Map
export 'src/core/map/map_models.dart';
export 'src/core/map/map_service.dart';

// Core - Menu (M1 — Windows-OS DB menu)
export 'src/core/menu/menu_item.dart';
export 'src/core/menu/mobile_menu_service.dart';
export 'src/core/menu/bootstrap_icon_map.dart';

// Core - Platform (M1 — platform switch)
export 'src/core/platform/platform_catalog.dart';
export 'src/core/platform/platform_context.dart';

// Core - Entity Engine (low-code builder data layer)
export 'src/core/entity/models/entity_type_config.dart';
export 'src/core/entity/models/generic_entity.dart';
export 'src/core/entity/entity_config_service.dart';
export 'src/core/entity/entity_data_service.dart';

// Core - Dynamic Form Engine (low-code builder data layer)
export 'src/core/form/models/form_field.dart';
export 'src/core/form/models/form_template.dart';
export 'src/core/form/form_template_service.dart';
export 'src/core/form/lookup_service.dart';

// Core - HR (ESS): leave / payroll / attendance (PDKS) / onboarding
export 'src/core/hr/hr_ess_service.dart';
export 'src/core/hr/models/leave_balance.dart';
export 'src/core/hr/models/leave_request_row.dart';
export 'src/core/hr/models/payslip.dart';
export 'src/core/hr/models/pdks_day.dart';
export 'src/core/hr/models/onboarding_task.dart';
// PHR ESS eksik-sayfa dalgası: profil / özet / belgeler / KVKK / takvim / değerlendirme
export 'src/core/hr/hr_profile_service.dart';
export 'src/core/hr/models/staff_profile.dart';
export 'src/core/hr/models/hr_summary.dart';
export 'src/core/hr/hr_documents_service.dart';
export 'src/core/hr/models/my_hr_document.dart';
export 'src/core/hr/models/kvkk_models.dart';
export 'src/core/hr/hr_calendar_review_service.dart';
export 'src/core/hr/models/leave_calendar_entry.dart';
export 'src/core/hr/models/review_queue_item.dart';
export 'src/core/hr/models/review_competency_rating.dart';
// PHR admin (yönetim) dalgası — İzin/Performans/Bordro/Org/PDKS/İşe-Alım/Teşvik
export 'src/core/hr/admin_leave_service.dart';
export 'src/core/hr/models/admin_leave_request_row.dart';
export 'src/core/hr/models/leave_type_row.dart';
export 'src/core/hr/models/holiday_row.dart';
export 'src/core/hr/admin_performance_service.dart';
export 'src/core/hr/models/performance_cycle.dart';
export 'src/core/hr/models/admin_performance_review.dart';
export 'src/core/hr/models/competency.dart';
export 'src/core/hr/admin_payroll_adjustment_service.dart';
export 'src/core/hr/admin_payroll_service.dart';
export 'src/core/hr/models/payroll_helpers.dart';
export 'src/core/hr/models/payroll_run.dart';
export 'src/core/hr/models/payroll_run_payslip.dart';
export 'src/core/hr/models/payroll_salary.dart';
export 'src/core/hr/models/payroll_parameter.dart';
export 'src/core/hr/models/payroll_adjustment.dart';
export 'src/core/hr/models/pushable_submission.dart';
export 'src/core/hr/models/payroll_cost_row.dart';
export 'src/core/hr/admin_org_service.dart';
export 'src/core/hr/models/admin_position.dart';
export 'src/core/hr/models/admin_organization.dart';
export 'src/core/hr/models/org_rollup_row.dart';
export 'src/core/hr/models/onboarding_instance_row.dart';
export 'src/core/hr/admin_attendance_service.dart';
export 'src/core/hr/models/admin_pdks_row.dart';
export 'src/core/hr/models/work_shift_row.dart';
export 'src/core/hr/models/staff_shift_row.dart';
export 'src/core/hr/models/attendance_record_row.dart';
export 'src/core/hr/models/puantaj_summary_row.dart';
export 'src/core/hr/models/attendance_lock_row.dart';
export 'src/core/hr/admin_recruitment_service.dart';
export 'src/core/hr/models/job_posting_row.dart';
export 'src/core/hr/models/job_application_row.dart';
export 'src/core/hr/models/pipeline_stage_group.dart';
export 'src/core/hr/models/hr_analytics_snapshot.dart';
export 'src/core/hr/admin_tesvik_kvkk_service.dart';
export 'src/core/hr/models/tesvik_accrual_row.dart';
export 'src/core/hr/models/tesvik_rule_row.dart';
export 'src/core/hr/models/arge_report_row.dart';
export 'src/core/hr/models/kvkk_overview_row.dart';

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
export 'src/presentation/widgets/lists/active_alarm_list.dart';
export 'src/presentation/widgets/lists/reset_alarm_list.dart';

// Presentation - Widgets - Navigation
export 'src/presentation/widgets/navigation/app_scaffold.dart';
export 'src/presentation/widgets/navigation/app_tab_bar.dart';
export 'src/presentation/widgets/navigation/app_bottom_sheet.dart';

// Presentation - Dynamic form + entity engine (Faz-1)
// Yalnız container widget'ı public API'ye çıkar; field-registry/context iç kalır
// (böylece iç dosyaların relative sibling import'ları redundant olmaz).
export 'src/presentation/dynamic_form/dynamic_form_widget.dart';

// Presentation - Dynamic report/page widget primitives (stat/chart/table)
export 'src/presentation/dyn_widgets/dyn_widgets.dart';
export 'src/presentation/dyn_widgets/dashboard_widget_view.dart';
export 'src/core/weather/weather_service.dart';
// Geofence tabanlı otomatik PDKS
export 'src/core/geofence/geofence_attendance_service.dart';
export 'src/core/geofence/work_geo_session_service.dart';
export 'src/presentation/shell/geofence/geofence_clock_card.dart';
export 'src/presentation/shell/geofence/geofence_map_card.dart';
export 'src/presentation/shell/geofence/work_geo_session_card.dart';
// Hesabım (Account) hub
export 'src/core/account/account_service.dart';
export 'src/core/account/models/credit_balance.dart';
export 'src/core/account/models/credit_transaction.dart';
export 'src/core/account/models/invoice.dart';
export 'src/core/account/models/invoice_summary.dart';
export 'src/core/account/models/storage_quota.dart';
export 'src/presentation/shell/account/account_hub_screen.dart';
export 'src/presentation/shell/account/credits_screen.dart';
export 'src/presentation/shell/account/invoices_screen.dart';
export 'src/presentation/shell/account/usage_screen.dart';

// Page Viewer (web-designed dashboard page templates)
export 'src/presentation/page_viewer/models/page_template.dart';
export 'src/presentation/page_viewer/page_viewer_screen.dart';

// Presentation - Report viewer (dr_report_templates → grid of dyn widgets)
export 'src/presentation/report_viewer/models/report_template.dart';
export 'src/presentation/report_viewer/report_viewer_screen.dart';

// Presentation - Shell (platform-nötr ekranlar + resolver) — Faz-0
// App-shell'ler (example_pms, example_phr…) bu ekranları paylaşır; domain
// ekranlarını `ScreenResolver.addResolver(...)` ile kaydeder.
export 'src/presentation/shell/screen_resolver.dart';
export 'src/presentation/shell/route_access.dart';
export 'src/presentation/shell/main_shell_screen.dart';
export 'src/presentation/shell/coming_soon_screen.dart';
export 'src/presentation/shell/portal_landing_screen.dart';
export 'src/presentation/shell/auth/login_screen.dart';
export 'src/presentation/shell/auth/accept_invite_screen.dart';
export 'src/presentation/shell/auth/request_access_screen.dart';
export 'src/presentation/shell/tenant/tenant_selector_screen.dart';
export 'src/presentation/shell/organization/organization_selector_screen.dart';
export 'src/presentation/shell/settings/settings_screen.dart';
export 'src/presentation/shell/settings/security_screen.dart';
export 'src/presentation/shell/profile/profile_hub_screen.dart';
export 'src/presentation/shell/profile/profile_edit_screen.dart';
export 'src/presentation/shell/home/home_screen.dart';
export 'src/presentation/shell/modules/modules_screen.dart';
export 'src/presentation/shell/notifications/notifications_screen.dart';
export 'src/presentation/shell/platform/platform_switcher_sheet.dart';
export 'src/presentation/shell/myspace/my_space_screen.dart';
export 'src/presentation/shell/search/global_search_screen.dart';
export 'src/presentation/shell/entities/entity_kanban_screen.dart';
export 'src/presentation/shell/entities/backlog_screen.dart';
export 'src/presentation/shell/workflow/approvals_inbox_screen.dart';
export 'src/core/ai/ai_models.dart';
export 'src/core/ai/ai_assistant_service.dart';
export 'src/presentation/shell/ai/ai_assistant_screen.dart';
export 'src/core/admin/admin_user_service.dart';
export 'src/core/admin/admin_staff_service.dart';
export 'src/presentation/shell/admin/user_management_screen.dart';
export 'src/presentation/shell/admin/staff_roster_screen.dart';
export 'src/core/admin/admin_rbac_service.dart';
export 'src/core/admin/admin_bug_report_service.dart';
export 'src/presentation/shell/admin/roles_screen.dart';
export 'src/presentation/shell/admin/bug_reports_screen.dart';
export 'src/presentation/shell/admin/menu_builder_screen.dart';
export 'src/core/admin/admin_integration_service.dart';
export 'src/core/admin/admin_audit_service.dart';
export 'src/core/admin/admin_notifications_hub_service.dart';
export 'src/core/admin/admin_subscription_service.dart';
export 'src/presentation/shell/admin/integrations_screen.dart';
export 'src/presentation/shell/admin/audit_log_screen.dart';
export 'src/presentation/shell/admin/notifications_hub_screen.dart';
export 'src/presentation/shell/admin/subscription_screen.dart';
export 'src/core/dashboard/personal_dashboard_service.dart';
export 'src/presentation/shell/dashboard/personal_dashboard_screen.dart';
export 'src/presentation/shell/language_picker.dart';
export 'src/presentation/shell/entities/entity_list_screen.dart';
export 'src/presentation/shell/entities/entity_detail_screen.dart';
export 'src/presentation/shell/entities/entity_detail_extensions.dart';
export 'src/presentation/shell/entities/entity_form_screen.dart';

// Presentation - Widgets - Feedback
export 'src/presentation/widgets/feedback/app_loading_indicator.dart';
export 'src/presentation/widgets/feedback/app_error_view.dart';
export 'src/presentation/widgets/feedback/app_empty_state.dart';
export 'src/presentation/widgets/feedback/async_view.dart';
export 'src/presentation/widgets/feedback/app_badge.dart';
export 'src/presentation/widgets/feedback/app_snackbar.dart';
export 'src/presentation/widgets/feedback/notification_badge.dart';
export 'src/presentation/widgets/feedback/offline_indicator.dart';
export 'src/presentation/widgets/feedback/error_boundary.dart';

// Presentation - Widgets - Charts
export 'src/presentation/widgets/charts/chart_container.dart';
export 'src/presentation/widgets/charts/alarm_bar_chart.dart';
export 'src/presentation/widgets/charts/alarm_pie_chart.dart';
export 'src/presentation/widgets/charts/log_line_chart.dart';
export 'src/presentation/widgets/charts/log_onoff_chart.dart';
export 'src/presentation/widgets/charts/multi_line_chart.dart';
export 'src/presentation/widgets/charts/multi_log_line_chart.dart';
export 'src/presentation/widgets/charts/multi_log_onoff_chart.dart';
export 'src/presentation/widgets/charts/full_screen_chart_view.dart';
export 'src/presentation/widgets/charts/alarm_mttr_card.dart';
export 'src/presentation/widgets/charts/alarm_top_offenders_card.dart';
export 'src/presentation/widgets/charts/alarm_heatmap_chart.dart';
export 'src/presentation/widgets/charts/alarm_priority_trend_chart.dart';
export 'src/presentation/widgets/charts/alarm_site_ranking_chart.dart';

// Presentation - Widgets - Map
export 'src/presentation/widgets/map/app_map.dart';
export 'src/presentation/widgets/map/app_map_controller.dart';
export 'src/presentation/widgets/map/map_marker_widget.dart';
export 'src/presentation/widgets/map/map_container.dart';
export 'src/presentation/widgets/map/map_controls.dart';
export 'src/presentation/widgets/map/geofence_circle.dart';

// Presentation - Widgets - Display
export 'src/presentation/widgets/display/app_avatar.dart';
export 'src/presentation/widgets/display/app_storage_avatar.dart';
export 'src/presentation/widgets/display/app_progress_bar.dart';
export 'src/presentation/widgets/display/app_chip.dart';
export 'src/presentation/shell/security/biometric_lock_gate.dart';
export 'src/presentation/shell/branding/branded_splash.dart';

// Core - Announcements (Duyurular)
export 'src/core/announcement/announcement_service.dart';
export 'src/presentation/shell/announcements/announcements_list_screen.dart';
export 'src/presentation/shell/announcements/announcement_detail_screen.dart';

// Core - Org Chart (Organizasyon şeması)
export 'src/core/orgchart/orgchart_service.dart';
export 'src/presentation/shell/orgchart/org_chart_screen.dart';
export 'src/core/announcement/announcement_notifier.dart';
export 'src/core/push/apns_registrar.dart';
