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
        if (!_isLoading && _errorMessage == null && _entity != null)
          AppIconButton(
            icon: Icons.swap_horiz,
            onPressed: _changeStatus,
          ),
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
          // FixFlow konum-tabanlı süre takibi — YALNIZ FixFlow platformunda +
          // worklog-etkin tiplerde. (enableWorklogs CRM/PPM tiplerinde de true
          // olduğundan tek başına gate DEĞİL: kart CRM activity / PPM task
          // detayında yanlışlıkla çıkıyordu — cross-domain sızıntı.)
          if (_config?.enableWorklogs == true &&
              sl<PlatformContext>().activePlatformCode == 'FIXFLOW') ...[
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
          // Yorum/tartışma thread'i — yorum-etkin tiplerde (CRM aktivite,
          // PPM issue vb.). Çekirdek paylaşılan primitif.
          if (_config?.enableComments == true) ...[
            const SizedBox(height: AppSpacing.md),
            CommentsThread(
              entityType: widget.typeCode,
              entityId: widget.id,
            ),
          ],
        ],
      ),
    );
  }

  /// Durum değiştir — status_definitions'tan seçenekleri yükleyip alt-sayfada
  /// sunar; seçilince `status-transition` EF ile günceller (geçiş doğrulamalı).
  Future<void> _changeStatus() async {
    final defs =
        await sl<EntityDataService>().loadStatusDefinitions(widget.typeCode);
    if (!mounted) return;
    if (defs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('entity.no_status', 'Bu tip için durum tanımı yok'))));
      return;
    }
    final current = _entity?.status;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(children: [
                Text(_t('entity.change_status', 'Durum değiştir'),
                    style: AppTypography.headline),
              ]),
            ),
            for (final d in defs)
              ListTile(
                leading: Icon(
                  (d['code'] as String?) == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: AppColors.primary,
                ),
                title: Text((d['name'] as String?) ??
                    (d['code'] as String?) ??
                    '—'),
                onTap: () => Navigator.of(ctx).pop(d['code'] as String?),
              ),
          ],
        ),
      ),
    );
    if (selected == null || selected == current || !mounted) return;
    try {
      await sl<EntityDataService>().updateStatus(
        entityType: widget.typeCode,
        entityId: widget.id,
        toStatus: selected,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('entity.status_updated', 'Durum güncellendi ✓'))));
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t('entity.status_failed', 'Durum güncellenemedi'))));
    }
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
                  _assigneeAvatar(entity.assignedToAvatar, assignee),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      assignee,
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            _buildFactsStrip(entity),
          ],
        ),
      ),
    );
  }

  /// Öncelik / story-point / sprint / üst-epik / termin gibi native alanları
  /// kompakt çip şeridi olarak gösterir (yalnız dolu olanlar). PPM görev
  /// detayları bu native kolonlarda tutulduğundan, form-şablonu bunları
  /// haritalamasa bile bilgiler burada görünür.
  Widget _buildFactsStrip(GenericEntity entity) {
    final chips = <Widget>[];
    void add(IconData icon, String? value) {
      if (value == null || value.trim().isEmpty) return;
      chips.add(_factChip(icon, value.trim()));
    }

    final priority = entity.priority;
    if (priority != null && priority.isNotEmpty) {
      add(Icons.flag_outlined, priority);
    }
    if (entity.storyPoints != null) {
      final p = entity.storyPoints!;
      final pStr = p == p.roundToDouble() ? p.toInt().toString() : p.toString();
      add(Icons.speed_outlined, '$pStr SP');
    }
    add(Icons.directions_run_outlined, entity.sprintName);
    add(Icons.account_tree_outlined, entity.parentSubject);
    final due = entity.dueDate;
    if (due != null) {
      add(Icons.event_outlined, AppClock.date(due));
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: chips),
    );
  }

  Widget _factChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.secondarySystemBackground(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.secondaryLabel(context)),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption2.copyWith(
              color: AppColors.primaryLabel(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Atanan kişi avatarı — 20px, çekirdek [AppStorageAvatar].
  Widget _assigneeAvatar(String? rawPath, String name) =>
      AppStorageAvatar(rawPath: rawPath, name: name, radius: 10);

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
