import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess_common.dart';

/// Çalışanın kendi İK belgeleri — "Belgelerim" (`/hr/my-documents`).
///
/// Zimmet / sözleşme / eğitim kayıtlarını salt-okuma listeler. Veri kaynağı:
/// `HrDocumentsService.myDocuments()` → RPC `fn_hr_my_documents` (web
/// `EssService.getMyDocuments` ile birebir sözleşme). Satırlar entity
/// kayıtlarıdır (dosya/storage-path taşımaz) → indirme değil, görüntüleme.
class MyDocumentsScreen extends StatefulWidget {
  const MyDocumentsScreen({super.key});

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  final _ctrl = AsyncViewController();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.my_docs.title', 'Belgelerim'),
      showBackButton: true,
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<MyHrDocument>>(
        controller: _ctrl,
        load: () => hrDocumentsService.myDocuments(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (d) => d.isEmpty,
        emptyIcon: Icons.folder_open_outlined,
        emptyTitle: essT('hr.my_docs.empty', 'Belge bulunamadı'),
        builder: (context, d) => _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, List<MyHrDocument> docs) {
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _DocumentCard(doc: docs[i]),
    );
  }
}

/// Belge tipi → ikon.
IconData _docIcon(String docType) {
  switch (docType) {
    case 'hr_asset':
      return Icons.laptop_mac_outlined;
    case 'hr_contract':
      return Icons.description_outlined;
    case 'hr_training':
      return Icons.school_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

/// Belge tipi → Türkçe etiket.
String _docTypeLabel(String docType) {
  switch (docType) {
    case 'hr_asset':
      return essT('hr.my_docs.assets', 'Zimmet');
    case 'hr_contract':
      return essT('hr.my_docs.contracts', 'Sözleşme');
    case 'hr_training':
      return essT('hr.my_docs.trainings', 'Eğitim');
    default:
      return essT('hr.my_docs.other', 'Belge');
  }
}

class _DocumentCard extends StatelessWidget {
  final MyHrDocument doc;

  const _DocumentCard({required this.doc});

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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_docIcon(doc.docType), color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title.isNotEmpty
                            ? doc.title
                            : _docTypeLabel(doc.docType),
                        style: AppTypography.headline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doc.code.isNotEmpty
                            ? '${_docTypeLabel(doc.docType)} · ${doc.code}'
                            : _docTypeLabel(doc.docType),
                        style: AppTypography.caption1
                            .copyWith(color: AppColors.tertiaryLabel(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (doc.status.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  AppBadge(
                    label: essStatusLabel(doc.status),
                    variant: essStatusVariant(doc.status),
                    size: AppBadgeSize.small,
                  ),
                ],
              ],
            ),
            if (doc.subtitle.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                doc.subtitle,
                style: AppTypography.footnote
                    .copyWith(color: AppColors.secondaryLabel(context)),
              ),
            ],
            if (doc.recordDate != null) ...[
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  Icon(Icons.event_outlined,
                      size: 14, color: AppColors.tertiaryLabel(context)),
                  const SizedBox(width: 4),
                  Text(
                    essDate(doc.recordDate),
                    style: AppTypography.caption1
                        .copyWith(color: AppColors.tertiaryLabel(context)),
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
