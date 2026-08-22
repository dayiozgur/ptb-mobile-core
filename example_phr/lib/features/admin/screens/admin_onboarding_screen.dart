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
  final _ctrl = AsyncViewController();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.onboarding.admin_title', 'Oryantasyon (Yönetim)'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<OnboardingInstanceRow>>(
        controller: _ctrl,
        load: () => adminOrgService.onboardingInstances(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (d) => d.isEmpty,
        emptyIcon: Icons.assignment_ind_outlined,
        emptyTitle: essT('hr.onboarding.admin_empty',
            'Oryantasyon süreci bulunamadı'),
        builder: (context, d) => _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, List<OnboardingInstanceRow> d) {
    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: d.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => AdminOnboardingInstanceCard(row: d[i]),
    );
  }
}
