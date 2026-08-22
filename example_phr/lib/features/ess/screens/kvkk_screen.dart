import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess_common.dart';

/// Çalışanın KVKK rıza kayıtları — "KVKK" (`/hr/kvkk`).
///
/// Rıza kataloğu (global + tenant) kullanıcının kendi kararlarıyla birleştirilip
/// zorunlu / opsiyonel olarak salt-okuma listelenir. Veri kaynağı:
/// `HrDocumentsService.myConsents()` (web `KvkkService` + `KvkkConsentComponent`
/// ile birebir okuma sözleşmesi: `kvkk_consent_types` + `kvkk_consents`).
///
/// v1 SALT-OKUMA: web'de grant/revoke yazımı vardır (RLS kendi staff'ına izin
/// verir); mobilde v1'de bağlanmadı (durum + tarih görüntülenir).
class KvkkScreen extends StatefulWidget {
  const KvkkScreen({super.key});

  @override
  State<KvkkScreen> createState() => _KvkkScreenState();
}

class _KvkkScreenState extends State<KvkkScreen> {
  final _ctrl = AsyncViewController();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('kvkk.title', 'KVKK Rızalarım'),
      showBackButton: true,
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<KvkkConsentRow>>(
        controller: _ctrl,
        load: () => hrDocumentsService.myConsents(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (d) => d.isEmpty,
        emptyBuilder: (context) => Center(
          child: AppEmptyState(
            icon: Icons.privacy_tip_outlined,
            title: essT('kvkk.empty_title', 'Rıza kaydı bulunamadı'),
            message: essT('kvkk.empty_message',
                'Görüntülenecek bir KVKK rıza kategorisi yok.'),
          ),
        ),
        builder: (context, d) => _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, List<KvkkConsentRow> rows) {
    final required = rows.where((r) => r.type.required).toList();
    final optional = rows.where((r) => !r.type.required).toList();

    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        if (required.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.priority_high,
            title: essT('kvkk.required', 'Zorunlu'),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...required.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ConsentCard(row: r),
              )),
        ],
        if (optional.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _SectionHeader(
            icon: Icons.check_circle_outline,
            title: essT('kvkk.optional', 'İsteğe bağlı'),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...optional.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ConsentCard(row: r),
              )),
        ],
      ],
    );
  }
}

/// Rıza durumu → Türkçe etiket.
String consentStateLabel(ConsentState state) {
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
AppBadgeVariant consentStateVariant(ConsentState state) {
  switch (state) {
    case ConsentState.granted:
      return AppBadgeVariant.success;
    case ConsentState.revoked:
      return AppBadgeVariant.error;
    case ConsentState.none:
      return AppBadgeVariant.neutral;
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.secondaryLabel(context)),
        const SizedBox(width: 6),
        Text(
          title,
          style: AppTypography.footnote.copyWith(
            color: AppColors.secondaryLabel(context),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ConsentCard extends StatelessWidget {
  final KvkkConsentRow row;

  const _ConsentCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final type = row.type;
    final consent = row.consent;
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
                  label: consentStateLabel(row.state),
                  variant: consentStateVariant(row.state),
                  size: AppBadgeSize.small,
                ),
              ],
            ),
            if (type.version != null && type.version!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'v${type.version}',
                style: AppTypography.caption1
                    .copyWith(color: AppColors.tertiaryLabel(context)),
              ),
            ],
            if (type.description != null && type.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                type.description!,
                style: AppTypography.footnote
                    .copyWith(color: AppColors.secondaryLabel(context)),
              ),
            ],
            if (row.state == ConsentState.granted &&
                consent?.grantedAt != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${essT('kvkk.granted_at', 'Onay tarihi')}: ${essDate(consent!.grantedAt)}',
                style: AppTypography.caption1
                    .copyWith(color: AppColors.tertiaryLabel(context)),
              ),
            ],
            if (row.state == ConsentState.revoked &&
                consent?.revokedAt != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${essT('kvkk.revoked_at', 'Geri alma tarihi')}: ${essDate(consent!.revokedAt)}',
                style: AppTypography.caption1
                    .copyWith(color: AppColors.tertiaryLabel(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
