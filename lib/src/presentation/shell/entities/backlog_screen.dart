import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

/// Bir entity tipinin kayıtlarını sürükle-bırak ile yeniden sıralayan Backlog
/// ekranı. Web `ptb-backlog` / scrum board'un mobil karşılığıdır: bir kaydı
/// yukarı/aşağı taşıyınca yeni sıra `form_submissions.backlog_rank`'e KALICI
/// yazılır (web `PtbSprintService.rerankBatch` ile aynı doğrudan-UPDATE yolu).
///
/// [typeCode] `entity_type_configs.code` değeridir (ör. `arge_proje`).
///
/// Kayıtlar `backlog_rank`'e göre sıralı gelir (NULL'lar sona). Sürükleme
/// önce YERELDE (optimistic) uygulanır, ardından sıra yazılır; yazım
/// başarısız olursa eski sıra geri alınır ve bir uyarı gösterilir.
class BacklogScreen extends StatefulWidget {
  const BacklogScreen({super.key, required this.typeCode});

  final String typeCode;

  @override
  State<BacklogScreen> createState() => _BacklogScreenState();
}

class _BacklogScreenState extends State<BacklogScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  EntityTypeConfig? _config;
  List<GenericEntity> _entities = [];

  @override
  void initState() {
    super.initState();
    _loadData();
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

      final entities = await dataService.loadBacklog(config);

      if (mounted) {
        setState(() {
          _config = config;
          _entities = entities;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load backlog (${widget.typeCode})', e);
      if (mounted) {
        setState(() {
          _errorMessage =
              '${sl<LocalizationService>().translate('common.error')}: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Sürükle-bırak sonrası: önce yerel sırayı güncelle (optimistic), sonra
  /// yeni sırayı `backlog_rank`'e yaz. Yazım başarısızsa eski sıraya dön.
  Future<void> _onReorder(int oldIndex, int newIndex) async {
    // ReorderableListView, aşağı taşımada newIndex'i bir fazla verir.
    if (newIndex > oldIndex) newIndex -= 1;
    if (newIndex == oldIndex) return;

    final previous = List<GenericEntity>.from(_entities);
    setState(() {
      final moved = _entities.removeAt(oldIndex);
      _entities.insert(newIndex, moved);
      _isSaving = true;
    });

    final orderedIds = _entities.map((e) => e.id).toList();

    try {
      await sl<EntityDataService>().reorderBacklog(orderedIds);
      if (mounted) setState(() => _isSaving = false);
    } catch (e) {
      Logger.error('Backlog reorder persist failed (${widget.typeCode})', e);
      if (!mounted) return;
      // Geri al: yazım başarısız → görünen sıra DB ile tutarsız kalmasın.
      setState(() {
        _entities = previous;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sıra kaydedilemedi. Lütfen tekrar deneyin.'),
        ),
      );
    }
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
      title: '$_title • Backlog',
      showBackButton: true,
      onBack: () => Navigator.of(context).pop(),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _isSaving ? null : _loadData,
        ),
      ],
      // CRITICAL: ReorderableListView doğrudan scaffold gövdesi — başka bir
      // scroll view içinde YOK, bounded yükseklik AppScaffold gövdesinden gelir.
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

    if (_entities.isEmpty) {
      return const Center(
        child: AppEmptyState(
          icon: Icons.reorder,
          title: 'Kayıt yok',
        ),
      );
    }

    return ReorderableListView.builder(
      padding: AppSpacing.screenPadding,
      itemCount: _entities.length,
      onReorder: _onReorder,
      itemBuilder: (context, index) {
        final entity = _entities[index];
        return _BacklogRow(
          key: ValueKey(entity.id),
          entity: entity,
          rank: index + 1,
          index: index,
        );
      },
    );
  }
}

/// Backlog satırı: sıra rozeti + başlık/kod + sürükleme tutamacı.
class _BacklogRow extends StatelessWidget {
  const _BacklogRow({
    required super.key,
    required this.entity,
    required this.rank,
    required this.index,
  });

  final GenericEntity entity;
  final int rank;
  final int index;

  @override
  Widget build(BuildContext context) {
    final code = entity.code;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Padding(
          padding: AppSpacing.cardInsets,
          child: Row(
            children: [
              // Sıra rozeti.
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.systemGray.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  '$rank',
                  style: AppTypography.caption1,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entity.displayTitle,
                      style: AppTypography.subheadline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      code != null && code.isNotEmpty
                          ? '$code • Sıra $rank'
                          : 'Sıra $rank',
                      style: AppTypography.caption2.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // Sürükleme tutamacı (uzun-basmadan da sürüklenebilir).
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_handle,
                  color: AppColors.tertiaryLabel(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
