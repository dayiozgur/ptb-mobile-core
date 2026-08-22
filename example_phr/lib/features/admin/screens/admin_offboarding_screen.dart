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
  final _ctrl = AsyncViewController();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('hr.offboarding.admin_title', 'İşten Çıkış (Yönetim)'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: AsyncView<List<OnboardingInstanceRow>>(
        controller: _ctrl,
        load: () => adminOrgService.offboardingInstances(),
        errorFallback: essT('common.data_load_error', 'Veriler yüklenemedi'),
        isEmpty: (d) => d.isEmpty,
        emptyIcon: Icons.logout_outlined,
        emptyTitle: essT('hr.offboarding.admin_empty',
            'İşten çıkış süreci bulunamadı'),
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
