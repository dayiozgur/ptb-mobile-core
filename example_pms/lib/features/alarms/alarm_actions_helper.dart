import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Alarm operatör aksiyonları (acknowledge / reset / inhibit) detay sheet'ini
/// AKSİYONLARLA açar.
///
/// active_alarms/global_alarms ekranları bu akışı kendi içlerinde barındırıyor;
/// bu helper aynı davranışı dashboard / provider-landing / site-landing gibi
/// ikincil giriş noktalarına taşır — oralarda sheet eskiden callback'siz (salt
/// görüntüleme) açılıyordu, operatör alarma müdahale edemiyordu.
///
/// [onRefresh] aksiyon sonrası çağıran ekranın listesini tazeler.
/// Yetki (admin veya alarmın org üyesi) sunucuda `fn_pms_alarm_*` SECDEF
/// RPC'lerinde denetlenir; reddi SnackBar'a döner (istemci rol-gate gerekmez).
Future<void> showAlarmActions(
  BuildContext context, {
  required Alarm alarm,
  Priority? priority,
  required Future<void> Function() onRefresh,
}) async {
  final loc = sl<LocalizationService>();

  Future<bool> confirm(String titleKey, String messageKey) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(loc.translate(titleKey)),
        content: Text(loc.translate(messageKey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text(loc.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: Text(loc.translate('common.confirm')),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> handleAction(
      Future<bool> Function() action, String successKey) async {
    String message;
    try {
      final ok = await action();
      message = loc.translate(ok ? successKey : 'alarm.action_failed');
    } catch (e) {
      Logger.error('Alarm action failed', e);
      message = loc.translate('alarm.action_error');
    }
    if (!context.mounted) return;
    Navigator.of(context).pop(); // detay sheet'i kapat
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    await onRefresh();
  }

  ActiveAlarmDetailSheet.show(
    context,
    alarm: alarm,
    priority: priority,
    onAcknowledge: () => handleAction(
      () => alarmService.acknowledgeAlarm(alarm.id),
      'alarm.ack_success',
    ),
    onReset: () async {
      final ok = await confirm(
          'alarm.confirm_reset_title', 'alarm.confirm_reset_message');
      if (!ok) return;
      await handleAction(
        () => alarmService.resetAlarm(alarm.id),
        'alarm.reset_success',
      );
    },
    onInhibitToggle: () async {
      final inhibited = alarm.inhibited == true;
      final ok = await confirm(
        inhibited
            ? 'alarm.confirm_uninhibit_title'
            : 'alarm.confirm_inhibit_title',
        inhibited
            ? 'alarm.confirm_uninhibit_message'
            : 'alarm.confirm_inhibit_message',
      );
      if (!ok) return;
      await handleAction(
        () => alarmService.inhibitAlarm(alarm.id, inhibit: !inhibited),
        inhibited ? 'alarm.uninhibit_success' : 'alarm.inhibit_success',
      );
    },
  );
}
