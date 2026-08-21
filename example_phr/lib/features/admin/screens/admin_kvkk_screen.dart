import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';

/// PHR yönetim "KVKK Yönetimi" görüntüleyici (salt-okuma, v1).
///
/// `/admin/kvkk` → org-geneli KVKK rıza özeti: her aktif rıza tipi
/// (`kvkk_consent_types`) için rıza veren (granted) tekil personel sayısı
/// (`kvkk_consents`), toplam aktif personele oranlanır (granted/total +
/// ilerleme çubuğu). Zorunlu/opsiyonel + global/tenant rozetleri. Veri kaynağı
/// [AdminTesvikKvkkService.kvkkOverview].
///
/// NOT: Bu ADMIN org-geneli bakıştır — çalışanın kendi rızalarını yönettiği
/// `/hr/kvkk` (KvkkScreen) ekranından ayrıdır. SALT-OKUMA.
class AdminKvkkScreen extends StatefulWidget {
  const AdminKvkkScreen({super.key});

  @override
  State<AdminKvkkScreen> createState() => _AdminKvkkScreenState();
}

class _AdminKvkkScreenState extends State<AdminKvkkScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<KvkkOverviewRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final rows = await adminTesvikKvkkService.kvkkOverview();
      if (mounted) {
        setState(() {
          _rows = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('AdminKvkkScreen yükleme hatası', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('kvkk.admin.title', 'KVKK Yönetimi'),
      showBackButton: true,
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _load),
      ],
      child: RefreshIndicator(
        onRefresh: _load,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(message: _errorMessage!, onRetry: _load),
      );
    }
    if (_rows.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppEmptyState(
                icon: Icons.privacy_tip_outlined,
                title: essT('kvkk.admin.empty', 'Rıza tipi bulunamadı'),
              ),
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _ConsentCard(row: _rows[i]),
    );
  }
}

class _ConsentCard extends StatelessWidget {
  final KvkkOverviewRow row;

  const _ConsentCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final ratio = row.coverageRatio;
    final Color barColor = ratio >= 1
        ? AppColors.success
        : (ratio > 0 ? AppColors.primary : AppColors.warning);
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
                    row.name.isNotEmpty ? row.name : row.code,
                    style: AppTypography.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: row.required
                      ? essT('kvkk.required', 'Zorunlu')
                      : essT('kvkk.optional', 'Opsiyonel'),
                  variant: row.required
                      ? AppBadgeVariant.warning
                      : AppBadgeVariant.neutral,
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            if (row.description != null && row.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                row.description!,
                style: AppTypography.footnote
                    .copyWith(color: AppColors.secondaryLabel(context)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Icon(Icons.people_outline,
                    size: 14, color: AppColors.tertiaryLabel(context)),
                const SizedBox(width: 4),
                Text(
                  '${row.grantedCount}/${row.totalStaff} ${essT('kvkk.admin.granted', 'rıza verdi')}',
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.primaryLabel(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(ratio * 100).round()}%',
                  style: AppTypography.footnote
                      .copyWith(color: AppColors.secondaryLabel(context)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: AppColors.separator(context),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
