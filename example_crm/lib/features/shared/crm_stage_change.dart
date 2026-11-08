import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../crm_common.dart';
import '../deals/crm_deal_reason.dart';
import '../pipeline/crm_stage_service.dart';

/// Aşama/durum değiştir akışı — web deal-pipeline `moveHandler` paritesi:
/// 1) yalnız `status_transitions`'ta izinli hedefler sunulur (rol süzgeçli,
///    sihirbaz-yalnız hedefler hariç), 2) geçiş yorum isterse yorum, onay
///    isterse onay alınır, 3) `status-transition` EF ile yürütülür.
///
/// Başarıda `true` döner (çağıran listeyi tazeler). Fırsat final duruma
/// geçerken kazanma/kaybetme nedeni sorulur ([CrmDealReason]).
Future<bool> showCrmStageChange(
  BuildContext context, {
  required CrmStageService stageService,
  required String entityType,
  required String entityId,
  required String? currentStatus,
  required List<CrmStage> stages,
  String? recordCode,
  DealReasonCollector? collectDealReason,
}) async {
  final from = currentStatus ?? '';
  final transitions = await stageService.availableTransitions(entityType, from);
  if (!context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  if (transitions.isEmpty) {
    messenger.showSnackBar(SnackBar(
        content: Text(crmT('crm.stage.no_moves',
            'Bu durumdan tanımlı bir geçiş yok'))));
    return false;
  }
  final byCode = {for (final s in stages) s.code: s};
  String nameOf(String code) =>
      byCode[code]?.name ?? EntityStatusLabels.humanize(code);

  final picked = await showModalBottomSheet<CrmTransition>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(children: [
              Expanded(
                child: Text(crmT('crm.stage.change', 'Durum değiştir'),
                    style: AppTypography.headline),
              ),
              if (from.isNotEmpty)
                Text(nameOf(from),
                    style: AppTypography.caption1
                        .copyWith(color: AppColors.secondaryLabel(ctx))),
            ]),
          ),
          for (final t in transitions)
            ListTile(
              leading: Icon(Icons.circle,
                  size: 14, color: byCode[t.toCode]?.color ?? AppColors.primary),
              title: Text(nameOf(t.toCode)),
              trailing: const Icon(Icons.arrow_forward, size: 18),
              onTap: () => Navigator.of(ctx).pop(t),
            ),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return false;

  String? comment;
  if (picked.requiresComment || picked.requiresConfirmation) {
    final message = crmTp('fixflow.kanban.moving_to',
        '"{{status}}" durumuna taşınacak', {'status': nameOf(picked.toCode)});
    if (picked.requiresComment) {
      comment = await _promptComment(context, message);
      if (comment == null || comment.trim().isEmpty) return false;
    } else {
      final ok = await _confirm(context, message);
      if (ok != true) return false;
    }
  }
  if (!context.mounted) return false;

  // Fırsat final duruma (kazanıldı/kaybedildi) → neden sor (web deal
  // workspace); neden geçiş başarılı olunca kaydedilir.
  Future<void> Function(BuildContext)? saveReason;
  if (entityType == 'deal' && byCode[picked.toCode]?.isFinal == true) {
    saveReason = await (collectDealReason ?? CrmDealReason.collect)(context,
        dealId: entityId, finalStatus: picked.toCode);
    if (saveReason == null || !context.mounted) return false;
  }

  try {
    await stageService.move(
      entityType: entityType,
      entityId: entityId,
      toStatus: picked.toCode,
      comment: comment,
    );
    messenger.showSnackBar(SnackBar(
        content: Text(entityType == 'deal'
            ? crmTp('crm.pipeline.status_updated',
                'Fırsat {{code}} aşamasına taşındı',
                {'code': recordCode ?? nameOf(picked.toCode)})
            : crmT('crm.stage.updated', 'Durum güncellendi'))));
    if (saveReason != null && context.mounted) await saveReason(context);
    return true;
  } catch (e) {
    Logger.error('crm stage move ($entityType/$entityId) hata', e);
    messenger.showSnackBar(SnackBar(
        content: Text(CrmStageLogic.isInvalidTransitionError(e)
            ? crmT('fixflow.kanban.invalid_transition',
                'Bu durum geçişi yapılamaz')
            : crmT('crm.pipeline.transition_error',
                'Kayıt taşınamadı — lütfen tekrar deneyin.'))));
    return false;
  }
}

/// [CrmDealReason.collect] imzası (testlerde değiştirilebilir).
typedef DealReasonCollector = Future<Future<void> Function(BuildContext)?> Function(
  BuildContext context, {
  required String dealId,
  required String finalStatus,
});

Future<bool?> _confirm(BuildContext context, String message) {
  return showDialog<bool>(
    context: context,
    builder: (dctx) => AlertDialog(
      title: Text(crmT('fixflow.kanban.confirm_move', 'Durum Değişikliği')),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text(crmT('crm.common.cancel', 'Vazgeç'))),
        TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: Text(crmT('fixflow.kanban.confirm', 'Onayla'))),
      ],
    ),
  );
}

/// Yorum istemi. Denetleyici bilinçli olarak dispose EDİLMEZ: diyalog kapanış
/// animasyonu sürerken dispose etmek "used after dispose" hatası verir;
/// dinleyicisiz denetleyici GC ile toplanır.
Future<String?> _promptComment(BuildContext context, String message) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dctx) => AlertDialog(
      title: Text(crmT('fixflow.kanban.confirm_move', 'Durum Değişikliği')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              labelText:
                  crmT('fixflow.kanban.comment_required', 'Yorum (zorunlu)'),
              hintText: crmT('fixflow.kanban.comment_placeholder',
                  'Durum değişikliği için açıklama yazın...'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: Text(crmT('crm.common.cancel', 'Vazgeç'))),
        TextButton(
            onPressed: () => Navigator.of(dctx).pop(ctrl.text.trim()),
            child: Text(crmT('fixflow.kanban.confirm', 'Onayla'))),
      ],
    ),
  );
}
