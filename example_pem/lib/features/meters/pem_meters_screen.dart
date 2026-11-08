import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../pem_common.dart';
import '../shared/pem_widgets.dart';
import 'pem_meter_tile.dart';
import 'pem_meters_service.dart';

/// PEM **Sayaçlar** (`/admin/energy/meters`) — aktif sayaçlar sahaya göre
/// gruplu; tesisat, rol, okuma türü, son değer, telemetri/manuel. Salt-okunur
/// (sayaç tanımı/düzenleme web'de).
class PemMetersScreen extends StatefulWidget {
  const PemMetersScreen({super.key, this.service, this.title});

  final PemMetersService? service;
  final String? title;

  @override
  State<PemMetersScreen> createState() => _PemMetersScreenState();
}

class _PemMetersScreenState extends State<PemMetersScreen> {
  late final PemMetersService _service = widget.service ?? PemMetersService();

  bool _loading = true;
  String? _error;
  List<PemMeterGroup> _groups = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final g = await _service.grouped();
      if (!mounted) return;
      setState(() {
        _groups = g;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      Logger.error('PEM meters load failed', e);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.title ?? pemT('energy.meter.list_title', 'Sayaçlar'),
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          tooltip: pemT('common.refresh', 'Yenile'),
          onPressed: () => _load(),
        ),
      ],
      child: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: AppLoadingIndicator());
    if (_error != null) {
      return PemErrorState(
        title: pemT('energy.meter.load_error', 'Sayaçlar yüklenemedi'),
        onRetry: () => _load(),
      );
    }
    if (_groups.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: PemScrollableEmpty(
          icon: Icons.speed_outlined,
          title: pemT('pem.mobile.no_meters', 'Henüz sayaç yok'),
          message: pemT('energy.meter.subtitle',
              'Tesislerinizi ve enerji sayaçlarınızı tanımlayın'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
        children: [
          for (final g in _groups)
            PemSection(
              title: '${g.siteName} (${g.meters.length})',
              child: Column(children: [
                for (final m in g.meters) PemMeterTile(meter: m),
              ]),
            ),
        ],
      ),
    );
  }
}
