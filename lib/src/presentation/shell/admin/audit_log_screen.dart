import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';


/// Admin — Denetim İzi (audit trail) görüntüleyici ekranı.
///
/// Web portal `/admin/audit-log` özelliğinin mobil, salt-okuma karşılığı.
/// [AdminAuditService] üzerinden son denetim kayıtlarını (RLS-scoped, en yeni
/// önce) listeler. Her kart işlem rozeti + varlık + aktör + tarih taşır; satıra
/// dokununca eski/yeni değer farkı (varsa) detay bottom-sheet'inde gösterilir.
/// Salt-okuma — denetim kayıtları mobilde değiştirilemez.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<AuditEntryRow> _entries = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await sl<AdminAuditService>().listAuditEntries();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Denetim kayıtları yüklenemedi';
        _loading = false;
      });
    }
  }

  // ── İşlem paleti (web badge sınıflarıyla eşleşir) ────────────────────────────

  Color _actionColor(String? action) {
    switch (action) {
      case 'create':
        return const Color(0xFF059669); // yeşil (success)
      case 'update':
        return const Color(0xFF2563EB); // mavi (info)
      case 'status_change':
        return const Color(0xFFD97706); // amber (warning)
      case 'delete':
        return const Color(0xFFDC2626); // kırmızı (danger)
      case 'export':
        return const Color(0xFF7C3AED); // mor
      default:
        return const Color(0xFF6B7280); // gri (secondary)
    }
  }

  String _actionLabel(String? action) {
    switch (action) {
      case 'create':
        return 'Oluşturma';
      case 'update':
        return 'Güncelleme';
      case 'status_change':
        return 'Durum Değişimi';
      case 'delete':
        return 'Silme';
      case 'export':
        return 'Dışa Aktarma';
      default:
        return action == null || action.isEmpty ? '—' : action;
    }
  }

  /// dd.MM.yyyy HH:mm (TR).
  String _formatDateTime(DateTime? d) {
    if (d == null) return '';
    final local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Denetim İzi',
      showBackButton: true,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildMessage(context, Icons.error_outline, _error!, retry: true);
    }
    if (_entries.isEmpty) {
      return _buildMessage(context, Icons.history_outlined, 'Kayıt yok');
    }

    // CRITICAL: ListView (bounded) — kaydırma içinde unbounded Flex YOK.
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) => _buildCard(context, _entries[i]),
      ),
    );
  }

  Widget _buildCard(BuildContext context, AuditEntryRow e) {
    return AppCard(
      variant: AppCardVariant.outlined,
      onTap: () => _showSheet(context, e),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _pill(_actionColor(e.action), _actionLabel(e.action)),
              Text(
                (e.entityType == null || e.entityType!.isEmpty)
                    ? '—'
                    : e.entityType!,
                style:
                    AppTypography.body.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(Icons.person_outline,
                  size: 14, color: AppColors.secondaryLabel(context)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  (e.actorName == null || e.actorName!.isEmpty)
                      ? 'Sistem'
                      : e.actorName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption1
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
              ),
              if (e.changedAt != null)
                Text(
                  _formatDateTime(e.changedAt),
                  style: AppTypography.caption1
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTypography.caption1
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Detay bottom-sheet (salt-okunur, eski/yeni fark) ──────────────────────

  void _showSheet(BuildContext context, AuditEntryRow e) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final diffs = _buildDiffs(e);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _pill(_actionColor(e.action), _actionLabel(e.action)),
                  Text(
                    (e.entityType == null || e.entityType!.isEmpty)
                        ? '—'
                        : e.entityType!,
                    style: AppTypography.title3
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _infoRow(ctx, Icons.person_outline, 'Aktör',
                  (e.actorName == null || e.actorName!.isEmpty)
                      ? 'Sistem'
                      : e.actorName!),
              _infoRow(ctx, Icons.event_outlined, 'Tarih',
                  e.changedAt == null ? '—' : _formatDateTime(e.changedAt)),
              if (e.entityId != null && e.entityId!.isNotEmpty)
                _infoRow(ctx, Icons.tag_outlined, 'Kayıt', e.entityId!),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Değişiklikler',
                style: AppTypography.subhead.copyWith(
                  color: AppColors.secondaryLabel(ctx),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (diffs.isEmpty)
                const Text(
                  'Ayrıntı yok',
                  style: AppTypography.body,
                )
              else
                ...diffs.map((d) => _diffRow(ctx, d)),
            ],
          ),
        );
      },
    );
  }

  /// old_values/new_values ya da changes jsonb'sinden alan-bazlı fark listesi.
  List<_FieldDiff> _buildDiffs(AuditEntryRow e) {
    final result = <_FieldDiff>[];

    // 1) `changes` = {field: {old, new}} ya da {field: value} biçiminde olabilir.
    final changes = e.changes;
    if (changes != null && changes.isNotEmpty) {
      changes.forEach((key, val) {
        if (val is Map) {
          final m = val.cast<String, dynamic>();
          if (m.containsKey('old') || m.containsKey('new')) {
            result.add(_FieldDiff(key, _fmt(m['old']), _fmt(m['new'])));
            return;
          }
        }
        result.add(_FieldDiff(key, null, _fmt(val)));
      });
      if (result.isNotEmpty) return result;
    }

    // 2) old_values + new_values kolonlarından türet.
    final oldV = e.oldValues ?? const {};
    final newV = e.newValues ?? const {};
    final keys = <String>{...oldV.keys, ...newV.keys};
    for (final k in keys) {
      final o = oldV[k];
      final n = newV[k];
      if (_fmt(o) == _fmt(n)) continue; // değişmeyen alanı gösterme
      result.add(_FieldDiff(k, _fmt(o), _fmt(n)));
    }
    return result;
  }

  static String _fmt(dynamic v) {
    if (v == null) return '—';
    if (v is String) return v.isEmpty ? '—' : v;
    return v.toString();
  }

  Widget _diffRow(BuildContext context, _FieldDiff d) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            d.field,
            style: AppTypography.subhead.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d.oldValue != null) ...[
                Expanded(
                  child: Text(
                    d.oldValue!,
                    style: AppTypography.caption1.copyWith(
                      color: const Color(0xFFDC2626),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward, size: 14),
                ),
              ],
              Expanded(
                child: Text(
                  d.newValue,
                  style: AppTypography.caption1
                      .copyWith(color: const Color(0xFF059669)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.secondaryLabel(context)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$label: ',
            style: AppTypography.subhead
                .copyWith(color: AppColors.secondaryLabel(context)),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  AppTypography.subhead.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(BuildContext context, IconData icon, String message,
      {bool retry = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.secondaryLabel(context)),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: AppTypography.body
                .copyWith(color: AppColors.secondaryLabel(context)),
          ),
          if (retry) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: _load, child: const Text('Tekrar dene')),
          ],
        ],
      ),
    );
  }
}

/// Tek bir alanın eski→yeni farkı (detay sheet).
class _FieldDiff {
  final String field;
  final String? oldValue;
  final String newValue;
  const _FieldDiff(this.field, this.oldValue, this.newValue);
}
