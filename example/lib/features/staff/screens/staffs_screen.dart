import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Personel Listesi Ekranı
///
/// Tüm personelleri listeler ve arama imkanı sunar.
class StaffsScreen extends StatefulWidget {
  const StaffsScreen({super.key});

  @override
  State<StaffsScreen> createState() => _StaffsScreenState();
}

class _StaffsScreenState extends State<StaffsScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<Staff> _allStaffs = [];
  List<Staff> _filteredStaffs = [];

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final tenantId = tenantService.currentTenantId;
    if (tenantId != null) {
      staffService.setTenant(tenantId);
    }

    try {
      final staffs = await staffService.getStaffs();

      if (mounted) {
        setState(() {
          _allStaffs = staffs;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load staffs', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Personeller yüklenirken hata oluştu';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    var filtered = List<Staff>.from(_allStaffs);

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((s) {
        final name = (s.name ?? '').toLowerCase();
        final fullName = (s.fullName ?? '').toLowerCase();
        final email = (s.email ?? '').toLowerCase();
        final phone = (s.phone ?? '').toLowerCase();
        final code = (s.code ?? '').toLowerCase();
        return name.contains(query) ||
            fullName.contains(query) ||
            email.contains(query) ||
            phone.contains(query) ||
            code.contains(query);
      }).toList();
    }

    _filteredStaffs = filtered;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppScaffold(
      title: 'Personeller',
      onBack: () => context.go('/home'),
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadData,
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/staff/new'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      child: Column(
        children: [
          // Arama Çubuğu
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            child: AppSearchBar(
              placeholder: 'Personel ara...',
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  _applyFilters();
                });
              },
            ),
          ),

          // Özet istatistikler
          if (!_isLoading && _errorMessage == null) _buildStats(brightness),

          const SizedBox(height: AppSpacing.sm),

          // Liste
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _buildContent(brightness),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(Brightness brightness) {
    final activeCount = _allStaffs.where((s) => s.isActive).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenHorizontal),
      child: Row(
        children: [
          _StatBadge(
            label: 'Aktif',
            count: activeCount,
            color: AppColors.success,
          ),
          const Spacer(),
          Text(
            '${_filteredStaffs.length}/${_allStaffs.length}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Brightness brightness) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(
          message: _errorMessage!,
          onRetry: _loadData,
        ),
      );
    }

    if (_filteredStaffs.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Icons.people_outline,
          title: _allStaffs.isEmpty ? 'Personel Yok' : 'Sonuç Bulunamadı',
          message: _allStaffs.isEmpty
              ? 'Henüz personel eklenmemiş.'
              : 'Arama kriterlerinize uygun personel bulunamadı.',
          actionLabel: _allStaffs.isEmpty ? 'Yeni Personel Ekle' : null,
          onAction: _allStaffs.isEmpty
              ? () => context.push('/staff/new')
              : null,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.sm,
      ),
      itemCount: _filteredStaffs.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final staff = _filteredStaffs[index];
        return _StaffCard(
          staff: staff,
          onTap: () => context.push('/staff/${staff.id}'),
        );
      },
    );
  }
}

class _StaffCard extends StatelessWidget {
  final Staff staff;
  final VoidCallback onTap;

  const _StaffCard({
    required this.staff,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isActive = staff.isActive;

    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: Text(
                  staff.initials ?? '?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // İçerik
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // İsim ve durum
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          staff.fullName ?? staff.name ?? '-',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary(brightness),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (isActive ? AppColors.success : AppColors.systemGray)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isActive ? 'Aktif' : 'Pasif',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isActive ? AppColors.success : AppColors.systemGray,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  // E-posta
                  if (staff.email != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 14,
                          color: AppColors.textSecondary(brightness),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            staff.email!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary(brightness),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                  ],

                  // Telefon
                  if (staff.phone != null)
                    Row(
                      children: [
                        Icon(
                          Icons.phone_outlined,
                          size: 14,
                          color: AppColors.textSecondary(brightness),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          staff.phone!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary(brightness),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right,
              color: AppColors.systemGray,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
