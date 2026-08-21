import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Hesap → Kullanım & Depolama görüntüleyici (salt-okuma). Web kullanım
/// sayfasının mobil karşılığı: depolama kotası kartı (kullanılan/limit +
/// ilerleme çubuğu, okunur boyut) ve opsiyonel AI kullanım özeti.
class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key});

  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  StorageQuota? _quota;
  Map<String, dynamic>? _aiUsage;
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
      final results = await Future.wait([
        accountService.storageQuota(),
        accountService.aiUsage(),
      ]);
      if (!mounted) return;
      setState(() {
        _quota = results[0] as StorageQuota?;
        _aiUsage = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Kullanım bilgisi yüklenemedi';
        _loading = false;
      });
    }
  }

  /// Bayt → okunur (B / KB / MB / GB).
  String _humanBytes(num bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double value = bytes.toDouble();
    int i = 0;
    while (value >= 1024 && i < units.length - 1) {
      value /= 1024;
      i++;
    }
    final str = i == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return '$str ${units[i]}';
  }

  num _aiNum(dynamic v) => (v is num) ? v : (num.tryParse('${v ?? ''}') ?? 0);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Kullanım & Depolama',
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _load),
      ],
      child: RefreshIndicator(onRefresh: _load, child: _content(context)),
    );
  }

  Widget _content(BuildContext context) {
    if (_loading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_error != null) {
      return AppErrorView(message: _error!, onRetry: _load);
    }

    final q = _quota;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          'Depolama',
          style: AppTypography.subhead.copyWith(
            color: AppColors.secondaryLabel(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (q == null)
          const AppEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Depolama bilgisi yok',
          )
        else
          _buildStorageCard(context, q),
        _buildAiSection(context),
      ],
    );
  }

  Widget _buildStorageCard(BuildContext context, StorageQuota q) {
    final fraction = q.usageFraction;
    final percent = fraction == null ? null : (fraction * 100).round();
    final barColor = (fraction != null && fraction >= 1)
        ? const Color(0xFFDC2626)
        : (fraction != null && fraction >= 0.8)
            ? const Color(0xFFD97706)
            : const Color(0xFF059669);

    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Kullanılan Alan',
                  style: AppTypography.body
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (percent != null)
                Text(
                  '%$percent',
                  style: AppTypography.subhead.copyWith(
                    color: barColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${_humanBytes(q.usedBytes)} / ${_humanBytes(q.limitBytes)}',
            style: AppTypography.title3.copyWith(fontWeight: FontWeight.w700),
          ),
          if (fraction != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 8,
                backgroundColor:
                    AppColors.secondaryLabel(context).withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _infoRow(context, 'Maks. dosya boyutu', _humanBytes(q.maxFileBytes)),
          if (q.perUserLimitBytes != null)
            _infoRow(
              context,
              'Kişisel kullanım',
              '${_humanBytes(q.perUserUsedBytes)} / ${_humanBytes(q.perUserLimitBytes!)}',
            ),
        ],
      ),
    );
  }

  Widget _buildAiSection(BuildContext context) {
    final ai = _aiUsage;
    if (ai == null) return const SizedBox.shrink();

    final builder = ai['builder'];
    final chat = ai['chat'];
    final builderCalls =
        builder is Map ? _aiNum(builder['calls']) : 0;
    final chatMessages =
        chat is Map ? _aiNum(chat['messages']) : 0;

    final quota = ai['quota'];
    String? quotaText;
    if (quota is Map) {
      final used = _aiNum(quota['used']);
      final limit = quota['monthly_limit'];
      if (limit != null) {
        quotaText = '${used.toInt()} / ${_aiNum(limit).toInt()}';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Kullanımı (bu ay)',
            style: AppTypography.subhead.copyWith(
              color: AppColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            variant: AppCardVariant.outlined,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _infoRow(context, 'Builder çağrıları',
                    builderCalls.toInt().toString()),
                _infoRow(
                    context, 'Sohbet mesajları', chatMessages.toInt().toString()),
                if (quotaText != null)
                  _infoRow(context, 'Aylık kota', quotaText),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.subhead
                  .copyWith(color: AppColors.secondaryLabel(context)),
            ),
          ),
          Text(
            value,
            style: AppTypography.subhead.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
