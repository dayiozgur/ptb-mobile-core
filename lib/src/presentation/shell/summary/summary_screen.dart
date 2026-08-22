import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../widgets/navigation/app_scaffold.dart';

/// **Genel özet/gösterge ekranı iskeleti** — dikey kaydırmalı kart listesi.
///
/// Platform-nötr: her uygulama (CRM/PPM/PHR) kendi kart setini ([KpiRowCard],
/// [AggregateChartCard] vb.) verir; iskelet yalnız başlık + kaydırma + boşluk
/// düzenini üstlenir. Kartların her biri kendini çeker (bağımsız yükleme/hata).
class SummaryScreen extends StatelessWidget {
  final String title;
  final List<Widget> cards;

  /// Geri gösterilsin mi (alt-sekme kökü ise false).
  final bool showBack;

  /// App-bar aksiyonları (ör. drill-down / yenile).
  final List<Widget>? actions;

  const SummaryScreen({
    super.key,
    required this.title,
    required this.cards,
    this.showBack = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      onBack: showBack ? () => context.pop() : null,
      actions: actions,
      child: ListView.separated(
        padding: AppSpacing.screenPadding,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, i) => cards[i],
      ),
    );
  }
}
