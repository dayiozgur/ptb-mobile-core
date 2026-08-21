import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../ess/ess_common.dart';
import 'admin_onboarding_instance_card.dart';

/// Admin "Oryantasyon (Yönetim)" görüntüleyici (salt-okuma, v1).
///
/// Web `OnboardingService.listInstances('onboarding')` yolunu aynalar
/// (`staff_onboarding_instances`, `type='onboarding'`). Her satır: personel
/// adı + şablon + durum rozeti + ilerleme (x/y bar) + başlangıç tarihi.
class AdminOnboardingScreen extends StatefulWidget {
  const AdminOnboardingScreen({super.key});

  @override
  State<AdminOnboardingScreen> createState() => _AdminOnboardingScreenState();
}

class _AdminOnboardingScreenState extends State<AdminOnboardingScreen> {
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
      final rows = await adminOrgService.onboardingInstances();
      if (mounted) {
        setState(() {
          _rows = rows;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('AdminOnboardingScreen yükleme hatası', e);
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
      title: essT('hr.onboarding.admin_title', 'Oryantasyon (Yönetim)'),
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
                icon: Icons.assignment_ind_outlined,
                title: essT('hr.onboarding.admin_empty',
                    'Oryantasyon süreci bulunamadı'),
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
