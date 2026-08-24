import 'package:flutter/material.dart' hide FormField;
import 'package:protoolbag_core/protoolbag_core.dart';

/// Bir entity tipinin kayıtlarını durum (status) kolonlarına göre gruplayan,
/// sürükle-bırak destekli Kanban panosu. Web `ptb-entity-kanban`'ın mobil
/// karşılığıdır: bir kartı başka bir durum kolonuna bırakınca
/// `form_submissions.status` güncellenir.
///
/// [typeCode] `entity_type_configs.code` değeridir (ör. `arge_proje`).
///
/// Kolon kaynağı: `status_definitions` (entity tipine göre, `sort_order` sıralı,
/// renk + etiket ile). Tanım yoksa kayıtlardaki distinct `status` değerlerinden
/// türetilir (fallback — asla çökmez).
class EntityKanbanScreen extends StatefulWidget {
  const EntityKanbanScreen({
    super.key,
    required this.typeCode,
    this.ancestorId,
    this.title,
    this.embedded = false,
  });

  final String typeCode;

  /// Bir sekme gövdesi olarak gömülürse (ör. PPM proje workspace) kendi
  /// AppScaffold'unu SARMAZ — yalnız içerik döner (iç-içe app-bar olmaz).
  final bool embedded;

  /// Opsiyonel proje/üst-öğe kapsamı — verilirse yalnız bu öğenin alt-ağacındaki
  /// kayıtlar gösterilir (PPM proje-scope board).
  final String? ancestorId;

  /// Opsiyonel başlık override (ör. proje adı).
  final String? title;

  @override
  State<EntityKanbanScreen> createState() => _EntityKanbanScreenState();
}

class _EntityKanbanScreenState extends State<EntityKanbanScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  EntityTypeConfig? _config;
  List<_StatusColumn> _columns = [];

  /// status code → o koldaki kayıtlar (yerel/optimistic durum).
  final Map<String, List<GenericEntity>> _byStatus = {};

  final _rt = RealtimeRefresher();

  @override
  void initState() {
    super.initState();
    _loadData();
    // Canlı-yenileme: form_submissions değişince panoyu sessizce tazele
    // (başka kullanıcı kart taşıdığında/eklediğinde pano güncel kalır).
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
            _columns = [];
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

      final defsRaw = await dataService.loadStatusDefinitions(config.code);
      // Kanban tüm kolonları göstermeli — default 50 sessizce kırpıyordu
      // (proje-scope filtresi eklenene dek makul üst sınır).
      final entities = await dataService.listEntities(config,
          limit: 200, ancestorId: widget.ancestorId);

      final columns = _buildColumns(defsRaw, entities);

      _byStatus.clear();
      for (final col in columns) {
        _byStatus[col.code] = [];
      }
      for (final entity in entities) {
        final key = _resolveColumnKey(entity.status, columns);
        _byStatus.putIfAbsent(key, () => []).add(entity);
      }

      if (mounted) {
        setState(() {
          _config = config;
          _columns = columns;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load kanban (${widget.typeCode})', e);
      if (mounted) {
        setState(() {
          _errorMessage =
              '${sl<LocalizationService>().translate('common.error')}: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Kolonları status_definitions'tan kur; yoksa kayıtların distinct
  /// status'larından türet (fallback).
  List<_StatusColumn> _buildColumns(
    List<Map<String, dynamic>> defsRaw,
    List<GenericEntity> entities,
  ) {
    if (defsRaw.isNotEmpty) {
      return defsRaw
          .map((row) => _StatusColumn(
                code: (row['code'] as String?) ?? '',
                label: (row['name'] as String?) ??
                    (row['code'] as String?) ??
                    '',
                color: _parseHexColor(row['color'] as String?),
              ))
          .where((c) => c.code.isNotEmpty)
          .toList();
    }

    // Fallback: kayıtlardaki distinct status değerleri.
    final seen = <String>{};
    final columns = <_StatusColumn>[];
    for (final entity in entities) {
      final status = entity.status;
      final key = (status == null || status.isEmpty) ? _noStatusKey : status;
      if (seen.add(key)) {
        columns.add(_StatusColumn(
          code: key,
          label: key == _noStatusKey
              ? sl<LocalizationService>().translate('common.no_records')
              : status!,
          color: null,
        ));
      }
    }
    if (columns.isEmpty) {
      columns.add(_StatusColumn(
        code: _noStatusKey,
        label: sl<LocalizationService>().translate('common.no_records'),
        color: null,
      ));
    }
    return columns;
  }

  /// Bir kaydın status'unu bilinen bir kolon koduna eşle; eşleşme yoksa ilk
  /// kolona (ya da "durum yok" anahtarına) düşür — kart asla kaybolmaz.
  String _resolveColumnKey(String? status, List<_StatusColumn> columns) {
    if (status != null && status.isNotEmpty) {
      for (final col in columns) {
        if (col.code == status) return status;
      }
    }
    if (columns.any((c) => c.code == _noStatusKey)) return _noStatusKey;
    return columns.isNotEmpty ? columns.first.code : _noStatusKey;
  }

  Future<void> _moveCard(GenericEntity entity, String targetStatus) async {
    // Fallback "durum yok" koluna bırakmayı yok say (gerçek status değil).
    if (targetStatus == _noStatusKey) return;

    String? sourceKey;
    for (final entry in _byStatus.entries) {
      if (entry.value.contains(entity)) {
        sourceKey = entry.key;
        break;
      }
    }
    if (sourceKey == null || sourceKey == targetStatus) return;

    final source = _byStatus[sourceKey]!;
    final target = _byStatus.putIfAbsent(targetStatus, () => []);
    final index = source.indexOf(entity);

    // Optimistic taşıma.
    setState(() {
      source.remove(entity);
      target.add(entity);
    });

    try {
      // Standalone entity'de entity.id == form_submissions.id == entityId.
      // entityType status_transitions grafiğini sürer (config.code'a düşer).
      await sl<EntityDataService>().updateStatus(
        entityType: entity.entityType ?? _config?.code ?? widget.typeCode,
        entityId: entity.id,
        toStatus: targetStatus,
      );
    } catch (e) {
      Logger.error('Kanban updateStatus failed (${entity.id})', e);
      // Geri al.
      if (!mounted) return;
      setState(() {
        target.remove(entity);
        source.insert(index.clamp(0, source.length), entity);
      });
      // Belirsiz "Hata" yerine gerçek sebebi göster. En sık durum: entity
      // tipinde bu from→to için `status_transitions` kuralı yok →
      // status-transition EF `ERR_INVALID_TRANSITION` döner (web ile aynı).
      final raw = e.toString();
      final invalidTransition = raw.contains('ERR_INVALID_TRANSITION') ||
          raw.toLowerCase().contains('transition');
      final msg = invalidTransition
          ? 'Bu durum geçişi tanımlı değil'
          : 'Durum güncellenemedi. Lütfen tekrar deneyin.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
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
    if (widget.embedded) return _buildContent();
    return AppScaffold(
      title: '${widget.title ?? _title} • Kanban',
      showBackButton: true,
      onBack: () => Navigator.of(context).pop(),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadData,
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

    if (_columns.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.view_kanban_outlined,
          title: sl<LocalizationService>().translate('common.no_records'),
        ),
      );
    }

    // CRITICAL: yatay kaydırıcı ListView; her kolon bounded genişlikte
    // SizedBox; kart listeleri kendi ListView'ları. Scroll view içinde
    // unbounded-height Flex YOK.
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      itemCount: _columns.length,
      itemBuilder: (context, index) {
        final column = _columns[index];
        final cards = _byStatus[column.code] ?? const [];
        return _KanbanColumn(
          column: column,
          cards: cards,
          onAccept: (entity) => _moveCard(entity, column.code),
        );
      },
    );
  }

  static const String _noStatusKey = '__no_status__';

  Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var value = hex.trim().replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }
}

/// Kanban durum kolonu (görsel model).
class _StatusColumn {
  const _StatusColumn({
    required this.code,
    required this.label,
    required this.color,
  });

  final String code;
  final String label;
  final Color? color;
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.column,
    required this.cards,
    required this.onAccept,
  });

  final _StatusColumn column;
  final List<GenericEntity> cards;
  final ValueChanged<GenericEntity> onAccept;

  @override
  Widget build(BuildContext context) {
    final accent = column.color ?? AppColors.systemGray;

    return SizedBox(
      width: 280,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Kolon başlığı: etiket + sayı, status rengiyle.
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border(
                  left: BorderSide(color: accent, width: 3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      column.label,
                      style: AppTypography.subheadline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    ),
                    child: Text(
                      '${cards.length}',
                      style: AppTypography.caption1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Kart listesi (bırakma hedefi).
            Expanded(
              child: DragTarget<GenericEntity>(
                onWillAcceptWithDetails: (details) =>
                    !cards.contains(details.data),
                onAcceptWithDetails: (details) => onAccept(details.data),
                builder: (context, candidate, rejected) {
                  final highlighted = candidate.isNotEmpty;
                  return Container(
                    decoration: BoxDecoration(
                      color: highlighted
                          ? accent.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: cards.isEmpty
                        ? _EmptyColumnPlaceholder()
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                            itemCount: cards.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final entity = cards[index];
                              return _DraggableCard(entity: entity);
                            },
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraggableCard extends StatelessWidget {
  const _DraggableCard({required this.entity});

  final GenericEntity entity;

  @override
  Widget build(BuildContext context) {
    final card = _EntityKanbanCard(entity: entity);
    return LongPressDraggable<GenericEntity>(
      data: entity,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 256, child: card),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: card),
      child: card,
    );
  }
}

class _EntityKanbanCard extends StatelessWidget {
  const _EntityKanbanCard({required this.entity});

  final GenericEntity entity;

  @override
  Widget build(BuildContext context) {
    final code = entity.code;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entity.displayTitle,
              style: AppTypography.subheadline,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
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
            if ((entity.assignedToName ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  AppStorageAvatar(
                    rawPath: entity.assignedToAvatar,
                    name: entity.assignedToName!,
                    radius: 8,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      entity.assignedToName!,
                      style: AppTypography.caption2.copyWith(
                        color: AppColors.secondaryLabel(context),
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
}

class _EmptyColumnPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          sl<LocalizationService>().translate('common.no_records'),
          textAlign: TextAlign.center,
          style: AppTypography.caption1.copyWith(
            color: AppColors.tertiaryLabel(context),
          ),
        ),
      ),
    );
  }
}
