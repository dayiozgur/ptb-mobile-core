import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess_common.dart';

/// Kullanıcının kişisel-veri (KVKK) genel bakışı — "Verilerim" (`/my-data`).
///
/// İşlenen kişisel-veri kategorilerini ve kullanıcının rıza durumunu SALT-OKUMA
/// özetler. Veri kaynağı: `HrDocumentsService.myDataOverview()` (web `KvkkService`
/// ile aynı `kvkk_consent_types` + `kvkk_consents` okuması).
///
/// NOT: Web tarafında ayrı bir kişisel-veri dışa-aktarım (data-export) RPC'si
/// YOKTUR → bu ekranda dışa-aktar butonu bulunmaz (salt görüntüleme).
class MyDataScreen extends StatefulWidget {
  const MyDataScreen({super.key});

  @override
  State<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends State<MyDataScreen> {
  final _ctrl = AsyncViewController();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('my_data.title', 'Verilerim'),
      showBackButton: true,
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<MyDataOverview>(
        controller: _ctrl,
        load: () => hrDocumentsService.myDataOverview(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (d) => d.categories.isEmpty,
        emptyIcon: Icons.shield_outlined,
        emptyTitle: essT('my_data.empty', 'Kişisel-veri kaydı bulunamadı'),
        builder: (context, d) => _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, MyDataOverview overview) {
    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        _SummaryCard(overview: overview),
        const SizedBox(height: AppSpacing.md),
        Text(
          essT('my_data.categories', 'Veri kategorileri'),
          style: AppTypography.footnote.copyWith(
            color: AppColors.secondaryLabel(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...overview.categories.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _CategoryCard(row: r),
            )),
      ],
    );
  }
}

/// Rıza durumu → Türkçe etiket (my-data bağlamı).
String _stateLabel(ConsentState state) {
  switch (state) {
    case ConsentState.granted:
      return essT('kvkk.state.granted', 'Onaylandı');
    case ConsentState.revoked:
      return essT('kvkk.state.revoked', 'Geri alındı');
    case ConsentState.none:
      return essT('kvkk.state.none', 'Karar verilmedi');
  }
}

/// Rıza durumu → rozet varyantı.
AppBadgeVariant _stateVariant(ConsentState state) {
  switch (state) {
    case ConsentState.granted:
      return AppBadgeVariant.success;
    case ConsentState.revoked:
      return AppBadgeVariant.error;
    case ConsentState.none:
      return AppBadgeVariant.neutral;
  }
}

class _SummaryCard extends StatelessWidget {
  final MyDataOverview overview;

  const _SummaryCard({required this.overview});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.privacy_tip_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    essT('my_data.overview_title',
                        'İşlenen kişisel verileriniz'),
                    style: AppTypography.headline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              essT('my_data.overview_desc',
                  'Aşağıda hesabınıza tanımlı KVKK veri kategorileri ve rıza durumunuz salt-okuma olarak listelenir.'),
              style: AppTypography.footnote
                  .copyWith(color: AppColors.secondaryLabel(context)),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                _StatTile(
                  value: overview.totalCategories.toString(),
                  label: essT('my_data.stat_total', 'Kategori'),
                ),
                _StatTile(
                  value: overview.grantedCount.toString(),
                  label: essT('my_data.stat_granted', 'Onaylı'),
                ),
                _StatTile(
                  value: overview.requiredCount.toString(),
                  label: essT('my_data.stat_required', 'Zorunlu'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;

  const _StatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppTypography.title3.copyWith(
              color: AppColors.primaryLabel(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.caption1
                .copyWith(color: AppColors.tertiaryLabel(context)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final KvkkConsentRow row;

  const _CategoryCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final type = row.type;
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
                    type.name,
                    style: AppTypography.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppBadge(
                  label: _stateLabel(row.state),
                  variant: _stateVariant(row.state),
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            Row(
              children: [
                if (type.required)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: AppBadge(
                      label: essT('kvkk.required', 'Zorunlu'),
                      variant: AppBadgeVariant.warning,
                      size: AppBadgeSize.small,
                    ),
                  ),
              ],
            ),
            if (type.description != null && type.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                type.description!,
                style: AppTypography.footnote
                    .copyWith(color: AppColors.secondaryLabel(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
