import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Portal'da tanımlı bir entity kaydının salt-okunur detayını gösterir.
///
/// Config [EntityConfigService] ile ([typeCode] → [EntityTypeConfig]), kayıt
/// [EntityDataService] ile çözülür. Gövde [DynamicFormWidget]'ı `viewMode`
/// ile sarar; başlık alanında durum/kod/atanan gösterilir. "Düzenle" aksiyonu
/// `/entities/<type>/<id>/edit` rotasına gider.
class EntityDetailScreen extends StatefulWidget {
  final String typeCode;
  final String id;

  const EntityDetailScreen({
    super.key,
    required this.typeCode,
    required this.id,
  });

  @override
  State<EntityDetailScreen> createState() => _EntityDetailScreenState();
}

class _EntityDetailScreenState extends State<EntityDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  EntityTypeConfig? _config;
  GenericEntity? _entity;
  FormTemplate? _template;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _t(String key, String fallback) {
    final v = sl<LocalizationService>().translate(key);
    return v == key ? fallback : v;
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final config = await sl<EntityConfigService>().getByCode(widget.typeCode);
      if (config == null) {
        if (mounted) {
          setState(() {
            _config = null;
            _entity = null;
            _template = null;
            _isLoading = false;
          });
        }
        return;
      }

      final tenantId = sl<TenantService>().currentTenantId;
      final dataService = sl<EntityDataService>();
      if (tenantId != null) {
        dataService.setTenant(tenantId);
      }

      final entity = await dataService.getEntity(config, widget.id);
      final template = await _resolveTemplate(config, entity);

      if (mounted) {
        setState(() {
          _config = config;
          _entity = entity;
          _template = template;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load entity (${widget.typeCode}/${widget.id})', e);
      if (mounted) {
        setState(() {
          _errorMessage =
              '${sl<LocalizationService>().translate('common.error')}: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Sırayla: kaydın `formTemplateId`'si → config'in varsayılanı → entity-type
  /// üzerinden ilk uygun şablon.
  Future<FormTemplate?> _resolveTemplate(
    EntityTypeConfig config,
    GenericEntity? entity,
  ) async {
    final service = sl<FormTemplateService>();

    final entityTemplateId = entity?.formTemplateId;
    if (entityTemplateId != null && entityTemplateId.isNotEmpty) {
      final t = await service.getById(entityTemplateId);
      if (t != null) return t;
    }

    final defaultId = config.defaultFormTemplateId;
    if (defaultId != null && defaultId.isNotEmpty) {
      final t = await service.getById(defaultId);
      if (t != null) return t;
    }

    return service.getByEntityType(config.code);
  }

  String get _title {
    final entity = _entity;
    if (entity != null) return entity.displayTitle;
    final config = _config;
    if (config != null) {
      final lang = sl<LocalizationService>().currentLocale.languageCode;
      return config.localizedName(lang);
    }
    return widget.typeCode;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _title,
      onBack: () => context.pop(),
      actions: [
        if (!_isLoading && _errorMessage == null && _template != null)
          AppIconButton(
            icon: Icons.edit_outlined,
            onPressed: () => context.push(
              '/entities/${widget.typeCode}/${widget.id}/edit',
            ),
          ),
      ],
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(
          message: _errorMessage!,
          onRetry: _loadData,
        ),
      );
    }

    final entity = _entity;
    if (entity == null) {
      return Center(
        child: AppEmptyState(
          icon: Icons.inbox_outlined,
          title: _t('common.no_records', 'Kayıt bulunamadı'),
        ),
      );
    }

    final template = _template;
    if (template == null) {
      return Center(
        child: AppEmptyState(
          icon: Icons.description_outlined,
          title: _t('entity.no_form', 'Bu tip için form tanımlı değil'),
        ),
      );
    }

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(entity),
          const SizedBox(height: AppSpacing.md),
          // FixFlow konum-tabanlı süre takibi — yalnız worklog-etkin tiplerde
          // ve FixFlow geofence tanımlıysa görünür (aksi halde kendini gizler).
          if (_config?.enableWorklogs == true) ...[
            WorkGeoSessionCard(
              workRequestId: widget.id,
              siteId: entity.fieldValues['site_id']?.toString() ??
                  entity.fieldValues['location_id']?.toString(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          DynamicFormWidget(
            template: template,
            initialValues: entity.fieldValues,
            viewMode: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(GenericEntity entity) {
    final status = entity.status;
    final code = entity.code;
    final assignee = entity.assignedToName;

    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entity.displayTitle,
                    style: AppTypography.headline,
                  ),
                ),
                if (status != null && status.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  AppBadge(
                    label: status,
                    variant: _statusVariant(status),
                    size: AppBadgeSize.small,
                  ),
                ],
              ],
            ),
            if (code != null && code.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                code,
                style: AppTypography.caption1.copyWith(
                  color: AppColors.secondaryLabel(context),
                ),
              ),
            ],
            if (assignee != null && assignee.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: AppColors.tertiaryLabel(context),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      assignee,
                      style: AppTypography.caption2.copyWith(
                        color: AppColors.tertiaryLabel(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  AppBadgeVariant _statusVariant(String status) {
    switch (status.toLowerCase()) {
      case 'done':
      case 'completed':
      case 'closed':
      case 'approved':
      case 'resolved':
      case 'active':
        return AppBadgeVariant.success;
      case 'in_progress':
      case 'in-progress':
      case 'pending':
      case 'open':
      case 'new':
        return AppBadgeVariant.info;
      case 'on_hold':
      case 'waiting':
      case 'review':
        return AppBadgeVariant.warning;
      case 'cancelled':
      case 'canceled':
      case 'rejected':
      case 'failed':
        return AppBadgeVariant.error;
      default:
        return AppBadgeVariant.neutral;
    }
  }
}
