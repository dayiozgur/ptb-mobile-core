import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Personel Detay Ekranı
///
/// Seçilen personelin tüm detaylarını ve ekiplerini gösterir.
class StaffDetailScreen extends StatefulWidget {
  final String staffId;

  const StaffDetailScreen({
    super.key,
    required this.staffId,
  });

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Staff? _staff;
  List<Team> _teams = [];

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
      teamService.setTenant(tenantId);
    }

    try {
      final staff = await staffService.getStaff(widget.staffId);

      List<Team> teams = [];
      try {
        teams = await teamService.getTeamsForStaff(widget.staffId);
      } catch (e) {
        Logger.error('Failed to load teams for staff', e);
      }

      if (mounted) {
        setState(() {
          _staff = staff;
          _teams = teams;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load staff', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Personel bilgileri yüklenirken hata oluştu';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteStaff() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Personeli Sil'),
        content: const Text('Bu personeli silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await staffService.deleteStaff(widget.staffId);
        if (mounted) {
          AppSnackbar.success(context, message: 'Personel silindi');
          context.go('/staff');
        }
      } catch (e) {
        Logger.error('Failed to delete staff', e);
        if (mounted) {
          AppSnackbar.error(context, message: 'Personel silinemedi');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppScaffold(
      title: _staff?.fullName ?? 'Personel',
      onBack: () => context.go('/staff'),
      actions: [
        if (_staff != null)
          AppIconButton(
            icon: Icons.edit,
            onPressed: () => context.push('/staff/${widget.staffId}/edit'),
          ),
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadData,
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _errorMessage != null
              ? Center(
                  child: AppErrorView(
                    message: _errorMessage!,
                    onRetry: _loadData,
                  ),
                )
              : _staff == null
                  ? Center(
                      child: AppEmptyState(
                        icon: Icons.person_outline,
                        title: 'Personel Bulunamadı',
                        message: 'İstenen personel bulunamadı.',
                      ),
                    )
                  : _buildContent(brightness),
    );
  }

  Widget _buildContent(Brightness brightness) {
    final staff = _staff!;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık kartı
            _buildHeader(staff, brightness),

            const SizedBox(height: AppSpacing.lg),

            // Bilgiler
            _buildInfoSection(staff, brightness),

            const SizedBox(height: AppSpacing.lg),

            // Ekipler
            _buildTeamsSection(brightness),

            const SizedBox(height: AppSpacing.lg),

            // Sil butonu
            Center(
              child: TextButton.icon(
                onPressed: _deleteStaff,
                icon: Icon(Icons.delete_outline, color: AppColors.error),
                label: Text(
                  'Personeli Sil',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Staff staff, Brightness brightness) {
    final isActive = staff.isActive;

    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            // Avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Center(
                child: Text(
                  staff.initials ?? '?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // İsim ve durum
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    staff.fullName ?? staff.name ?? '-',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  if (staff.code != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      staff.code!,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary(brightness),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (isActive ? AppColors.success : AppColors.systemGray)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.success : AppColors.systemGray,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isActive ? 'Aktif' : 'Pasif',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isActive ? AppColors.success : AppColors.systemGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(Staff staff, Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bilgiler',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (staff.code != null)
              _DetailRow(
                icon: Icons.tag,
                label: 'Kod',
                value: staff.code!,
              ),
            if (staff.email != null)
              _DetailRow(
                icon: Icons.email_outlined,
                label: 'E-posta',
                value: staff.email!,
              ),
            if (staff.phone != null)
              _DetailRow(
                icon: Icons.phone_outlined,
                label: 'Telefon',
                value: staff.phone!,
              ),
            if (staff.address != null)
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Adres',
                value: staff.address!,
              ),
            if (staff.town != null)
              _DetailRow(
                icon: Icons.map_outlined,
                label: 'İlçe',
                value: staff.town!,
              ),
            if (staff.website != null)
              _DetailRow(
                icon: Icons.language,
                label: 'Web Sitesi',
                value: staff.website!,
              ),
            if (staff.description != null)
              _DetailRow(
                icon: Icons.description_outlined,
                label: 'Açıklama',
                value: staff.description!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamsSection(Brightness brightness) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Ekipler',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_teams.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_teams.isEmpty)
          AppCard(
            child: Padding(
              padding: AppSpacing.cardInsets,
              child: Center(
                child: Text(
                  'Bu personel henüz bir ekibe atanmamış.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ),
            ),
          )
        else
          ..._teams.map((team) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  child: Padding(
                    padding: AppSpacing.cardInsets,
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.group, color: AppColors.info, size: 22),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                team.name ?? '-',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary(brightness),
                                ),
                              ),
                              if (team.code != null) ...[
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  team.code!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary(brightness),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (team.memberCount != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.systemGray6,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 14,
                                  color: AppColors.textSecondary(brightness),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${team.memberCount}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary(brightness),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              )),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary(brightness)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary(brightness),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: valueColor ?? AppColors.textPrimary(brightness),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
