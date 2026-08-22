import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import 'backlog_screen.dart';
import 'entity_kanban_screen.dart';

/// Portal'da (low-code builder) tanımlanmış bir entity tipinin kayıtlarını
/// gezilebilir bir liste olarak gösterir.
///
/// [typeCode] `entity_type_configs.code` değeridir (ör. `arge_proje`). Config
/// [EntityConfigService] ile çözülür, kayıtlar [EntityDataService] ile
/// listelenir. Satıra dokununca detay rotasına (`/entities/<type>/<id>`)
/// gidilir; detay ekranı başka bir ajan tarafından sağlanır — bu ekran onu
/// import ETMEZ, string rota üzerinden çözer.
class EntityListScreen extends StatefulWidget {
  final String typeCode;

  const EntityListScreen({super.key, required this.typeCode});

  @override
  State<EntityListScreen> createState() => _EntityListScreenState();
}

class _EntityListScreenState extends State<EntityListScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  EntityTypeConfig? _config;
  List<GenericEntity> _entities = [];
  String _search = '';

  final _rt = RealtimeRefresher();

  @override
  void initState() {
    super.initState();
    _loadData();
    // Canlı-yenileme: form_submissions değişince listeyi sessizce tazele.
    _rt.start(
      table: 'form_submissions',
      onChange: () {
        if (mounted) _loadData(silent: true);
      },
    );
  }

  @override
  void dispose() {
    _rt.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final config = await sl<EntityConfigService>().getByCode(widget.typeCode);
      if (config == null) {
        if (mounted) {
          setState(() {
            _config = null;
            _entities = [];
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

      final entities = await dataService.listEntities(
        config,
        search: _search.trim().isEmpty ? null : _search.trim(),
      );

      if (mounted) {
        setState(() {
          _config = config;
          _entities = entities;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load entities (${widget.typeCode})', e);
      if (mounted) {
        setState(() {
          _errorMessage =
              '${sl<LocalizationService>().translate('common.error')}: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _search = value;
    _loadData();
  }

  String get _title {
    final config = _config;
    if (config == null) return widget.typeCode;
    final lang = sl<LocalizationService>().currentLocale.languageCode;
    return config.localizedName(lang);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _title,
      onBack: () => context.pop(),
      actions: [
        if (_config != null)
          AppIconButton(
            icon: Icons.view_kanban_outlined,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EntityKanbanScreen(typeCode: widget.typeCode),
              ),
            ),
          ),
        if (_config != null)
          AppIconButton(
            icon: Icons.reorder,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BacklogScreen(typeCode: widget.typeCode),
              ),
            ),
          ),
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadData,
        ),
      ],
      floatingActionButton: _config == null
          ? null
          : FloatingActionButton(
              onPressed: () =>
                  context.push('/entities/${widget.typeCode}/create'),
              tooltip: sl<LocalizationService>().translate('common.create'),
              child: const Icon(Icons.add),
            ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: AppSearchField(
              placeholder:
                  sl<LocalizationService>().translate('common.search'),
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _buildContent(),
            ),
          ),
        ],
      ),
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

    if (_entities.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppEmptyState(
                icon: Icons.inbox_outlined,
                title: sl<LocalizationService>().translate('common.no_records'),
                message: _search.trim().isNotEmpty
                    ? sl<LocalizationService>()
                        .translate('common.no_results_found')
                    : null,
              ),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _entities.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final entity = _entities[index];
        return _EntityCard(
          entity: entity,
          onTap: () => context.push(
            '/entities/${widget.typeCode}/${entity.id}',
          ),
        );
      },
    );
  }
}

class _EntityCard extends StatelessWidget {
  final GenericEntity entity;
  final VoidCallback onTap;

  const _EntityCard({
    required this.entity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = entity.status;
    final priority = entity.priority;
    final assignee = entity.assignedToName;

    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entity.displayTitle,
                          style: AppTypography.headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                  if (entity.code != null && entity.code!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      entity.code!,
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ],
                  if ((assignee != null && assignee.isNotEmpty) ||
                      (priority != null && priority.isNotEmpty)) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        if (assignee != null && assignee.isNotEmpty) ...[
                          _miniAvatar(context, entity.assignedToAvatar, assignee),
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
                        if (priority != null && priority.isNotEmpty) ...[
                          if (assignee != null && assignee.isNotEmpty)
                            const SizedBox(width: AppSpacing.sm),
                          Icon(
                            Icons.flag_outlined,
                            size: 14,
                            color: AppColors.tertiaryLabel(context),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            priority,
                            style: AppTypography.caption2.copyWith(
                              color: AppColors.tertiaryLabel(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  /// Liste satırı için 14px atanan-avatarı — çekirdek [AppStorageAvatar].
  Widget _miniAvatar(BuildContext context, String? rawPath, String name) =>
      AppStorageAvatar(rawPath: rawPath, name: name, radius: 7);

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
