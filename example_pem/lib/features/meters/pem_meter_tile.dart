import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../pem_common.dart';
import '../shared/pem_models.dart';

/// Sayaç satırı: tesisat · rol · birim, telemetri/manuel rozeti, son değer.
class PemMeterTile extends StatelessWidget {
  const PemMeterTile({super.key, required this.meter});

  final PemMeter meter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = meter;
    final role = (m.meterRole ?? '').isEmpty
        ? null
        : pemT('energy.meter.role.${m.meterRole}',
            EntityStatusLabels.humanize(m.meterRole!));
    final kind = (m.readingKind ?? '').isEmpty
        ? null
        : pemT('energy.meter.kind.${m.readingKind}',
            EntityStatusLabels.humanize(m.readingKind!));
    final sub = [role, kind, m.unit]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(_icon(m.utilityType), color: theme.colorScheme.primary),
      title: Text(pemUtilityLabel(m.utilityType)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sub.isNotEmpty) Text(sub),
          if (m.lastValue != null)
            Text('${pemNum(m.lastValue, decimals: 2)} ${m.unit ?? ''} · '
                '${pemDateTime(m.lastValueAt)}'),
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(m.isTelemetry ? Icons.memory : Icons.edit_outlined, size: 14),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            m.isTelemetry
                ? pemT('energy.meter.telemetry', 'Telemetri')
                : pemT('energy.meter.manual', 'Manuel'),
            style: theme.textTheme.labelSmall,
          ),
        ]),
      ),
    );
  }

  static IconData _icon(String? utility) {
    switch ((utility ?? '').toLowerCase()) {
      case 'water':
        return Icons.water_drop_outlined;
      case 'gas':
      case 'natural_gas':
        return Icons.local_fire_department_outlined;
      case 'steam':
        return Icons.cloud_outlined;
      default:
        return Icons.bolt;
    }
  }
}
