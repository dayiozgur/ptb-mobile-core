import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tenant = tenantService.currentTenant;
    final user = authService.currentUser;

    return AppScaffold(
      title: tenant?.name ?? 'Ana Sayfa',
      showBackButton: false,
      actions: [
        AppIconButton(
          icon: Icons.notifications_outlined,
          onPressed: () {
            AppSnackbar.showInfo(
              context,
              message: 'Bildirimler yakında eklenecek',
            );
          },
        ),
        AppIconButton(
          icon: Icons.settings_outlined,
          onPressed: () => context.push('/settings'),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async {
          // Refresh data
          await Future.delayed(const Duration(seconds: 1));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome card
              _WelcomeCard(user: user, tenant: tenant),

              const SizedBox(height: AppSpacing.lg),

              // Quick stats
              AppSectionHeader(
                title: 'Özet',
                action: TextButton(
                  onPressed: () {},
                  child: const Text('Tümünü Gör'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const _QuickStats(),

              const SizedBox(height: AppSpacing.lg),

              // Quick actions
              AppSectionHeader(title: 'Hızlı İşlemler'),
              const SizedBox(height: AppSpacing.sm),
              const _QuickActions(),

              const SizedBox(height: AppSpacing.lg),

              // Recent activity
              AppSectionHeader(
                title: 'Son Aktiviteler',
                action: TextButton(
                  onPressed: () {},
                  child: const Text('Tümünü Gör'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              const _RecentActivity(),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final dynamic user;
  final Tenant? tenant;

  const _WelcomeCard({this.user, this.tenant});

  @override
  Widget build(BuildContext context) {
    final greeting = _getGreeting();

    return AppCard(
      variant: AppCardVariant.filled,
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Row(
          children: [
            AppAvatar(
              name: user?.email ?? 'User',
              size: AppAvatarSize.large,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: AppTypography.headline,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    user?.email ?? '',
                    style: AppTypography.subheadline.copyWith(
                      color: AppColors.secondaryLabel(context),
                    ),
                  ),
                  if (tenant != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    AppBadge(
                      label: tenant!.name,
                      variant: AppBadgeVariant.primary,
                      size: AppBadgeSize.small,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Günaydın!';
    } else if (hour < 18) {
      return 'İyi Günler!';
    } else {
      return 'İyi Akşamlar!';
    }
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MetricCard(
            title: 'Toplam Kayıt',
            value: '1,234',
            icon: Icons.inventory_2_outlined,
            trend: MetricTrend.up,
            trendValue: '+12%',
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: MetricCard(
            title: 'Aktif',
            value: '892',
            icon: Icons.check_circle_outline,
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          AppListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.add, color: AppColors.primary),
            ),
            title: 'Yeni Kayıt Ekle',
            subtitle: 'Yeni bir kayıt oluşturun',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              AppSnackbar.showInfo(context, message: 'Yeni kayıt ekleniyor...');
            },
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          AppListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.search, color: AppColors.success),
            ),
            title: 'Kayıt Ara',
            subtitle: 'Mevcut kayıtlarda arama yapın',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              AppSnackbar.showInfo(context, message: 'Arama açılıyor...');
            },
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          AppListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.bar_chart, color: AppColors.warning),
            ),
            title: 'Raporlar',
            subtitle: 'Detaylı raporları görüntüleyin',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              AppSnackbar.showInfo(context, message: 'Raporlar yükleniyor...');
            },
          ),
        ],
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context) {
    final activities = [
      _Activity(
        icon: Icons.add_circle,
        color: AppColors.success,
        title: 'Yeni kayıt eklendi',
        subtitle: '5 dakika önce',
      ),
      _Activity(
        icon: Icons.edit,
        color: AppColors.primary,
        title: 'Kayıt güncellendi',
        subtitle: '1 saat önce',
      ),
      _Activity(
        icon: Icons.person_add,
        color: AppColors.info,
        title: 'Yeni kullanıcı davet edildi',
        subtitle: '2 saat önce',
      ),
      _Activity(
        icon: Icons.delete,
        color: AppColors.error,
        title: 'Kayıt silindi',
        subtitle: 'Dün',
      ),
    ];

    return AppCard(
      child: Column(
        children: activities.asMap().entries.map((entry) {
          final index = entry.key;
          final activity = entry.value;
          final isLast = index == activities.length - 1;

          return Column(
            children: [
              AppListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: activity.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(activity.icon, color: activity.color, size: 20),
                ),
                title: activity.title,
                subtitle: activity.subtitle,
              ),
              if (!isLast) Divider(height: 1, color: AppColors.separator(context)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _Activity {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _Activity({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });
}
