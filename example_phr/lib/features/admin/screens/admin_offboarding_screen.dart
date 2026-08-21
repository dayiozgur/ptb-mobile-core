import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';
import 'admin_onboarding_instance_card.dart';

/// Admin "İşten Çıkış (Yönetim)" görüntüleyici (salt-okuma, v1).
///
/// KAYNAK NOTU: İşten-çıkış AYRI bir tablo değildir. Web
/// `OffboardingAdminComponent`, oryantasyonla AYNI dört `staff_onboarding_*`
/// tablosunu `type='offboarding'` ile ayrılmış biçimde kullanır (kanıtlanmış
/// checklist motoru + RLS yeniden kullanılır, yeni şema yok). Bu ekran da
/// servisin `offboardingInstances()` (kind='offboarding') yolunu tüketir.
/// Her satır: personel + şablon + durum + ilerleme + başlangıç tarihi.
class AdminOffboardingScreen extends StatefulWidget {
  const AdminOffboardingScreen({super.key});

  @override
  State<AdminOffboardingScreen> createState() => _AdminOffboardingScreenState();
}

class _AdminOffboardingScreenState extends State<AdminOffboardingScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<OnboardingInstanceRow> _rows = [];

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
      final rows = await adminOrgService.offboardingInstances();
      if (mounted) {
        setState(() {
          _rows = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('AdminOffboardingScreen yükleme hatası', e);
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
      title: essT('hr.offboarding.admin_title', 'İşten Çıkış (Yönetim)'),
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
                icon: Icons.logout_outlined,
                title: essT('hr.offboarding.admin_empty',
                    'İşten çıkış süreci bulunamadı'),
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
      itemBuilder: (_, i) => AdminOnboardingInstanceCard(row: _rows[i]),
    );
  }
}
