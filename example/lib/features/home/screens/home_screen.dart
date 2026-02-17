import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  int _organizationCount = 0;
  int _siteCount = 0;
  int _unitCount = 0;
  int _memberCount = 0;
  int _unreadNotifications = 0;
  List<ActivityLog> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    try {
      final tenantId = tenantService.currentTenantId;
      final organizationId = organizationService.currentOrganizationId;
      final siteId = siteService.currentSiteId;

      // Paralel olarak verileri yükle
      final futures = <Future>[];

      if (tenantId != null) {
        futures.add(
          organizationService.getOrganizations(tenantId).then((orgs) {
            _organizationCount = orgs.length;
          }),
        );
      }

      if (organizationId != null) {
        futures.add(
          siteService.getSites(organizationId).then((sites) {
            _siteCount = sites.length;
          }),
        );
      }

      if (siteId != null) {
        futures.add(
          unitService.getUnits(siteId).then((units) {
            _unitCount = units.length;
          }),
        );
      }

      // Üye sayısını al (tenant_users'dan)
      if (tenantId != null) {
        futures.add(
          _getMemberCount(tenantId).then((count) {
            _memberCount = count;
          }),
        );

        // Son aktiviteleri al
        futures.add(
          activityService.getRecentActivities(tenantId, limit: 5).then((activities) {
            _recentActivities = activities;
          }),
        );
      }

      // Okunmamış bildirim sayısını al
      final userId = authService.currentUser?.id;
      if (userId != null) {
        futures.add(
          notificationService.getUnreadCount(userId).then((count) {
            _unreadNotifications = count;
          }),
        );
      }

      await Future.wait(futures);
    } catch (e) {
      Logger.error('Failed to load dashboard data', e);
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<int> _getMemberCount(String tenantId) async {
    try {
      final response = await Supabase.instance.client
          .from('tenant_users')
          .select('id')
          .eq('tenant_id', tenantId)
          .eq('status', 'active');
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenant = tenantService.currentTenant;
    final organization = organizationService.currentOrganization;
    final site = siteService.currentSite;
    final user = authService.currentUser;

    return AppScaffold(
      title: tenant?.name ?? 'Ana Sayfa',
      showBackButton: false,
      actions: [
        AppIconButton(
          icon: Icons.search,
          onPressed: () => context.push('/search'),
        ),
        NotificationIconBadge(
          count: _unreadNotifications,
          onTap: () => context.push('/notifications'),
        ),
        AppIconButton(
          icon: Icons.settings_outlined,
          onPressed: () => context.push('/settings'),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome card
              _WelcomeCard(user: user, tenant: tenant),

              const SizedBox(height: AppSpacing.lg),

              // Current context card
              _CurrentContextCard(
                organization: organization,
                site: site,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Dashboard stats
              AppSectionHeader(
                title: 'Genel Bakış',
                action: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              _DashboardStats(
                organizationCount: _organizationCount,
                siteCount: _siteCount,
                unitCount: _unitCount,
                memberCount: _memberCount,
                isLoading: _isLoading,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Quick actions
              AppSectionHeader(title: 'Hızlı İşlemler'),
              const SizedBox(height: AppSpacing.sm),
              _QuickActions(
                onNavigateOrganizations: () => context.go('/organizations'),
                onNavigateSites: () => context.go('/sites'),
                onNavigateUnits: () => context.go('/units'),
                onNavigateMembers: () => context.go('/members'),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Map Section
              AppSectionHeader(title: 'Harita'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                onTap: () => context.push('/map'),
                child: Padding(
                  padding: AppSpacing.cardInsets,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.map_rounded, color: Colors.teal),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Site Haritasi',
                              style: AppTypography.headline,
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'Tum siteleri harita uzerinde gorun',
                              style: AppTypography.subheadline.copyWith(
                                color: AppColors.secondaryLabel(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.tertiaryLabel(context),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              // IoT Section
              AppSectionHeader(
                title: 'IoT Yönetimi',
                action: TextButton(
                  onPressed: () => context.go('/iot'),
                  child: const Text('Tümü'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _IotQuickAccess(),

              const SizedBox(height: AppSpacing.lg),

              // Work Management Section
              AppSectionHeader(
                title: 'İş Yönetimi',
              ),
              const SizedBox(height: AppSpacing.sm),
              _WorkManagementSection(),

              const SizedBox(height: AppSpacing.lg),

              // UI Component Showcase
              AppSectionHeader(title: 'Geliştirici Araçları'),
              const SizedBox(height: AppSpacing.sm),
              _DevToolsCard(),

              const SizedBox(height: AppSpacing.lg),

              // Hierarchy navigation
              AppSectionHeader(title: 'Hiyerarşi'),
              const SizedBox(height: AppSpacing.sm),
              _HierarchyCard(
                tenant: tenant,
                organization: organization,
                site: site,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Recent activity
              AppSectionHeader(
                title: 'Son Aktiviteler',
                action: _recentActivities.isNotEmpty
                    ? TextButton(
                        onPressed: () => context.push('/activity'),
                        child: const Text('Tümünü Gör'),
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              _RecentActivity(activities: _recentActivities, isLoading: _isLoading),

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
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            GestureDetector(
              onTap: () => context.push('/profile'),
              child: AppAvatar(
                name: user?.email ?? 'User',
                size: AppAvatarSize.large,
              ),
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
                    Row(
                      children: [
                        AppBadge(
                          label: tenant!.plan.name.toUpperCase(),
                          variant: _getPlanBadgeVariant(tenant!.plan),
                          size: AppBadgeSize.small,
                        ),
                        if (tenant!.isTrial) ...[
                          const SizedBox(width: AppSpacing.xs),
                          AppBadge(
                            label: 'Deneme',
                            variant: AppBadgeVariant.warning,
                            size: AppBadgeSize.small,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            AppIconButton(
              icon: Icons.swap_horiz,
              onPressed: () => context.go('/tenant-select'),
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

  AppBadgeVariant _getPlanBadgeVariant(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return AppBadgeVariant.secondary;
      case SubscriptionPlan.basic:
        return AppBadgeVariant.info;
      case SubscriptionPlan.professional:
        return AppBadgeVariant.primary;
      case SubscriptionPlan.enterprise:
        return AppBadgeVariant.success;
    }
  }
}

class _CurrentContextCard extends StatelessWidget {
  final Organization? organization;
  final Site? site;

  const _CurrentContextCard({
    this.organization,
    this.site,
  });

  @override
  Widget build(BuildContext context) {
    if (organization == null && site == null) {
      return const SizedBox.shrink();
    }

    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: AppColors.primary, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Mevcut Konum',
                  style: AppTypography.caption1.copyWith(
                    color: AppColors.secondaryLabel(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (organization != null) ...[
              _ContextItem(
                icon: Icons.apartment,
                label: 'Organizasyon',
                value: organization!.name,
                onTap: () => context.go('/organizations'),
              ),
            ],
            if (site != null) ...[
              if (organization != null) const SizedBox(height: AppSpacing.xs),
              _ContextItem(
                icon: Icons.location_city,
                label: 'Site',
                value: site!.name,
                onTap: () => context.go('/sites'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContextItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ContextItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.tertiaryLabel(context)),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '$label: ',
              style: AppTypography.caption1.copyWith(
                color: AppColors.tertiaryLabel(context),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: AppTypography.subheadline,
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.tertiaryLabel(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardStats extends StatelessWidget {
  final int organizationCount;
  final int siteCount;
  final int unitCount;
  final int memberCount;
  final bool isLoading;

  const _DashboardStats({
    required this.organizationCount,
    required this.siteCount,
    required this.unitCount,
    required this.memberCount,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Organizasyon',
                value: isLoading ? '-' : '$organizationCount',
                icon: Icons.apartment,
                color: Colors.blue,
                onTap: () => context.go('/organizations'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricCard(
                title: 'Site',
                value: isLoading ? '-' : '$siteCount',
                icon: Icons.location_city,
                color: Colors.green,
                onTap: () => context.go('/sites'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Alan',
                value: isLoading ? '-' : '$unitCount',
                icon: Icons.space_dashboard,
                color: Colors.orange,
                onTap: () => context.go('/units'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: MetricCard(
                title: 'Üye',
                value: isLoading ? '-' : '$memberCount',
                icon: Icons.people,
                color: Colors.purple,
                onTap: () => context.go('/members'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onNavigateOrganizations;
  final VoidCallback onNavigateSites;
  final VoidCallback onNavigateUnits;
  final VoidCallback onNavigateMembers;

  const _QuickActions({
    required this.onNavigateOrganizations,
    required this.onNavigateSites,
    required this.onNavigateUnits,
    required this.onNavigateMembers,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          _QuickActionItem(
            icon: Icons.apartment,
            color: Colors.blue,
            title: 'Organizasyonlar',
            subtitle: 'Organizasyonları yönetin',
            onTap: onNavigateOrganizations,
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          _QuickActionItem(
            icon: Icons.location_city,
            color: Colors.green,
            title: 'Siteler',
            subtitle: 'Siteleri görüntüleyin ve yönetin',
            onTap: onNavigateSites,
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          _QuickActionItem(
            icon: Icons.space_dashboard,
            color: Colors.orange,
            title: 'Alanlar',
            subtitle: 'Alan hiyerarşisini yönetin',
            onTap: onNavigateUnits,
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          _QuickActionItem(
            icon: Icons.people,
            color: Colors.purple,
            title: 'Üyeler ve Davetler',
            subtitle: 'Ekip üyelerini yönetin',
            onTap: onNavigateMembers,
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: title,
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _HierarchyCard extends StatelessWidget {
  final Tenant? tenant;
  final Organization? organization;
  final Site? site;

  const _HierarchyCard({
    this.tenant,
    this.organization,
    this.site,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          children: [
            _HierarchyLevel(
              level: 1,
              icon: Icons.business,
              label: 'Tenant',
              value: tenant?.name ?? 'Seçilmedi',
              isActive: tenant != null,
              onTap: () => context.go('/tenant-select'),
            ),
            _HierarchyConnector(isActive: tenant != null),
            _HierarchyLevel(
              level: 2,
              icon: Icons.apartment,
              label: 'Organizasyon',
              value: organization?.name ?? 'Seçilmedi',
              isActive: organization != null,
              onTap: () => context.go('/organizations'),
            ),
            _HierarchyConnector(isActive: organization != null),
            _HierarchyLevel(
              level: 3,
              icon: Icons.location_city,
              label: 'Site',
              value: site?.name ?? 'Seçilmedi',
              isActive: site != null,
              onTap: () => context.go('/sites'),
            ),
            _HierarchyConnector(isActive: site != null),
            _HierarchyLevel(
              level: 4,
              icon: Icons.space_dashboard,
              label: 'Alan',
              value: unitService.currentUnit?.name ?? 'Seçilmedi',
              isActive: unitService.currentUnit != null,
              onTap: () => context.go('/units'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HierarchyLevel extends StatelessWidget {
  final int level;
  final IconData icon;
  final String label;
  final String value;
  final bool isActive;
  final VoidCallback onTap;

  const _HierarchyLevel({
    required this.level,
    required this.icon,
    required this.label,
    required this.value,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.tertiaryLabel(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 18,
                  color: isActive
                      ? AppColors.primary
                      : AppColors.tertiaryLabel(context),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.caption2.copyWith(
                      color: AppColors.tertiaryLabel(context),
                    ),
                  ),
                  Text(
                    value,
                    style: AppTypography.subheadline.copyWith(
                      color: isActive ? null : AppColors.tertiaryLabel(context),
                      fontWeight: isActive ? FontWeight.w500 : null,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.tertiaryLabel(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _HierarchyConnector extends StatelessWidget {
  final bool isActive;

  const _HierarchyConnector({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 22),
      child: Row(
        children: [
          Container(
            width: 2,
            height: 16,
            color: isActive
                ? AppColors.primary.withOpacity(0.3)
                : AppColors.tertiaryLabel(context).withOpacity(0.2),
          ),
        ],
      ),
    );
  }
}

class _IotQuickAccess extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _IotQuickCard(
            icon: Icons.developer_board,
            label: 'Controllers',
            color: Colors.blue,
            onTap: () => context.go('/iot/controllers'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _IotQuickCard(
            icon: Icons.storage,
            label: 'Providers',
            color: Colors.green,
            onTap: () => context.go('/iot/providers'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _IotQuickCard(
            icon: Icons.data_object,
            label: 'Variables',
            color: Colors.orange,
            onTap: () => context.go('/iot/variables'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _IotQuickCard(
            icon: Icons.account_tree,
            label: 'Workflows',
            color: Colors.purple,
            onTap: () => context.go('/iot/workflows'),
          ),
        ),
      ],
    );
  }
}

class _IotQuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _IotQuickCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.xs),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.caption2.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  final List<ActivityLog> activities;
  final bool isLoading;

  const _RecentActivity({
    required this.activities,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return AppCard(
        child: Padding(
          padding: AppSpacing.cardInsets,
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (activities.isEmpty) {
      return AppCard(
        child: Padding(
          padding: AppSpacing.cardInsets,
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.history,
                  size: 40,
                  color: AppColors.tertiaryLabel(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Henüz aktivite yok',
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.secondaryLabel(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                    color: _getActionColor(activity.action).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getActionIcon(activity.action),
                    color: _getActionColor(activity.action),
                    size: 20,
                  ),
                ),
                title: activity.displayText,
                subtitle: activity.relativeTime,
              ),
              if (!isLast)
                Divider(height: 1, color: AppColors.separator(context)),
            ],
          );
        }).toList(),
      ),
    );
  }

  IconData _getActionIcon(ActivityAction action) {
    switch (action) {
      case ActivityAction.login:
        return Icons.login;
      case ActivityAction.logout:
        return Icons.logout;
      case ActivityAction.create:
        return Icons.add_circle;
      case ActivityAction.update:
        return Icons.edit;
      case ActivityAction.delete:
        return Icons.delete;
      case ActivityAction.enable:
        return Icons.check_circle;
      case ActivityAction.disable:
        return Icons.block;
      case ActivityAction.export_:
        return Icons.download;
      case ActivityAction.import_:
        return Icons.upload;
      default:
        return Icons.info;
    }
  }

  Color _getActionColor(ActivityAction action) {
    switch (action) {
      case ActivityAction.login:
        return AppColors.success;
      case ActivityAction.logout:
        return AppColors.warning;
      case ActivityAction.create:
        return AppColors.info;
      case ActivityAction.update:
        return AppColors.primary;
      case ActivityAction.delete:
        return AppColors.error;
      case ActivityAction.enable:
        return AppColors.success;
      case ActivityAction.disable:
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }
}

class _DevToolsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          AppListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.palette_outlined, color: Colors.deepPurple),
            ),
            title: 'Bileşen Kataloğu',
            subtitle: 'Tüm UI bileşenlerini keşfedin',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/showcase'),
          ),
          Divider(height: 1, color: AppColors.separator(context)),
          AppListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.analytics_outlined, color: Colors.amber),
            ),
            title: 'Raporlar',
            subtitle: 'İstatistikler ve analizler',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/reports'),
          ),
        ],
      ),
    );
  }
}

class _WorkManagementSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _WorkManagementCard(
            icon: Icons.assignment_outlined,
            label: 'İş Talepleri',
            color: Colors.indigo,
            onTap: () => context.go('/work-requests'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _WorkManagementCard(
            icon: Icons.calendar_month_outlined,
            label: 'Takvim',
            color: Colors.teal,
            onTap: () => context.go('/calendar'),
          ),
        ),
      ],
    );
  }
}

class _WorkManagementCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _WorkManagementCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTypography.subheadline.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
