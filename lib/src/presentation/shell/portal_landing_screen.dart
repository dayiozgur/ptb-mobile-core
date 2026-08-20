import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// CUSTOMER (ROLE_CUSTOMER) için kısıtlı portal açılış ekranı.
///
/// Müşteri rolü PMS operatör ekranlarını göremez (web: yalnız `/portal/*`).
/// Coarse-role router guard, müşteriyi buraya yönlendirir.
class PortalLandingScreen extends StatelessWidget {
  const PortalLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = sl<LocalizationService>();
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('portal.title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: loc.translate('auth.logout'),
            onPressed: () async {
              await CoreInitializer.signOut();
              sessionCoarseRole.value = null;
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_pin_circle_outlined,
                  size: 72, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                loc.translate('portal.welcome'),
                textAlign: TextAlign.center,
                style: AppTypography.title2,
              ),
              const SizedBox(height: 8),
              Text(
                loc.translate('portal.restricted_message'),
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.secondaryLabel(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
