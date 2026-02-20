import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// Ekip Detay Ekranı
///
/// Seçilen ekibin tüm detaylarını ve üyelerini gösterir.
class TeamDetailScreen extends StatefulWidget {
  final String teamId;

  const TeamDetailScreen({
    super.key,
    required this.teamId,
  });

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Team? _team;
  List<TeamMember> _members = [];

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
      teamService.setTenant(tenantId);
    }

    try {
      final team = await teamService.getTeam(widget.teamId);
      final members = await teamService.getTeamMembers(widget.teamId);

      if (mounted) {
        setState(() {
          _team = team;
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load team', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Ekip yüklenirken hata oluştu';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteTeam() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ekibi Sil'),
        content: const Text('Bu ekibi silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
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
        await teamService.deleteTeam(widget.teamId);
        if (mounted) {
          AppSnackbar.success(context, message: 'Ekip silindi');
          context.go('/teams');
        }
      } catch (e) {
        Logger.error('Failed to delete team', e);
        if (mounted) {
          AppSnackbar.error(context, message: 'Ekip silinemedi');
        }
      }
    }
  }

  Future<void> _showAddMemberSheet() async {
    final tenantId = tenantService.currentTenantId;
    if (tenantId != null) {
      staffService.setTenant(tenantId);
    }

    List<Staff> allStaff = [];
    bool isLoadingStaff = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLg),
        ),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          if (isLoadingStaff) {
            staffService.getStaffs().then((staffList) {
              // Mevcut üyeleri filtrele
              final existingStaffIds = _members.map((m) => m.staffId).toSet();
              final availableStaff = staffList
                  .where((s) => !existingStaffIds.contains(s.id))
                  .toList();
              setModalState(() {
                allStaff = availableStaff;
                isLoadingStaff = false;
              });
            }).catchError((e) {
              Logger.error('Failed to load staff', e);
              setModalState(() {
                isLoadingStaff = false;
              });
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.85,
            expand: false,
            builder: (context, scrollController) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.systemGray4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  Text(
                    'Üye Ekle',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(Theme.of(context).brightness),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  if (isLoadingStaff)
                    const Expanded(
                      child: Center(child: CircularProgressIndicator.adaptive()),
                    )
                  else if (allStaff.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          'Eklenebilecek personel bulunamadı',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary(Theme.of(context).brightness),
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.separated(
                        controller: scrollController,
                        itemCount: allStaff.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: AppColors.separator(context),
                        ),
                        itemBuilder: (context, index) {
                          final staff = allStaff[index];
                          return ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.person,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              staff.fullName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: staff.email != null
                                ? Text(
                                    staff.email!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary(
                                          Theme.of(context).brightness),
                                    ),
                                  )
                                : null,
                            trailing: Icon(
                              Icons.add_circle_outline,
                              color: AppColors.primary,
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              await _addMember(staff.id);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addMember(String staffId) async {
    try {
      await teamService.addTeamMember(
        teamId: widget.teamId,
        staffId: staffId,
      );
      if (mounted) {
        AppSnackbar.success(context, message: 'Üye eklendi');
        await _loadData();
      }
    } catch (e) {
      Logger.error('Failed to add team member', e);
      if (mounted) {
        AppSnackbar.error(context, message: 'Üye eklenemedi');
      }
    }
  }

  Future<void> _removeMember(TeamMember member) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Üyeyi Çıkar'),
        content: Text(
          '${member.staffName ?? 'Bu üyeyi'} ekipten çıkarmak istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await teamService.removeTeamMember(
          teamId: widget.teamId,
          staffId: member.staffId,
        );
        if (mounted) {
          AppSnackbar.success(context, message: 'Üye çıkarıldı');
          await _loadData();
        }
      } catch (e) {
        Logger.error('Failed to remove team member', e);
        if (mounted) {
          AppSnackbar.error(context, message: 'Üye çıkarılamadı');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return AppScaffold(
      title: _team?.name ?? 'Ekip',
      onBack: () => context.go('/teams'),
      actions: [
        if (_team != null)
          AppIconButton(
            icon: Icons.edit,
            onPressed: () => context.push('/teams/${widget.teamId}/edit'),
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
              : _team == null
                  ? Center(
                      child: AppEmptyState(
                        icon: Icons.groups_outlined,
                        title: 'Ekip Bulunamadı',
                        message: 'İstenen ekip bulunamadı.',
                      ),
                    )
                  : _buildContent(brightness),
    );
  }

  Widget _buildContent(Brightness brightness) {
    final team = _team!;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık ve Durum
            _buildHeader(team, brightness),

            const SizedBox(height: AppSpacing.lg),

            // Bilgi Kartı
            _buildInfoSection(team, brightness),

            const SizedBox(height: AppSpacing.lg),

            // Üyeler
            _buildMembersSection(brightness),

            const SizedBox(height: AppSpacing.lg),

            // Sil butonu
            _buildDeleteButton(brightness),

            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Team team, Brightness brightness) {
    final isActive = team.isActive;

    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge'ler
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                if (team.code != null && team.code!.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.systemGray6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      team.code!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary(brightness),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // Başlık
            Text(
              team.name ?? '-',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(brightness),
              ),
            ),

            if (team.description != null && team.description!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                team.description!,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary(brightness),
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(Team team, Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ekip Bilgileri',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _DetailRow(
              icon: Icons.work_outline,
              label: 'Bağımsız',
              value: team.independent == true ? 'Evet' : 'Hayır',
            ),
            if (team.createdAt != null)
              _DetailRow(
                icon: Icons.calendar_today_outlined,
                label: 'Oluşturulma',
                value: _formatDateTime(team.createdAt!),
              ),
            if (team.updatedAt != null)
              _DetailRow(
                icon: Icons.update,
                label: 'Güncellenme',
                value: _formatDateTime(team.updatedAt!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersSection(Brightness brightness) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Üyeler',
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
                    '${_members.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _showAddMemberSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add, size: 16, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          'Üye Ekle',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            if (_members.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: Text(
                    'Henüz üye eklenmemiş',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                ),
              )
            else
              ..._members.map((member) => _MemberItem(
                    member: member,
                    onRemove: () => _removeMember(member),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton(Brightness brightness) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _deleteTeam,
        icon: Icon(Icons.delete_outline, color: AppColors.error),
        label: Text(
          'Ekibi Sil',
          style: TextStyle(color: AppColors.error),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: BorderSide(color: AppColors.error),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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

class _MemberItem extends StatelessWidget {
  final TeamMember member;
  final VoidCallback onRemove;

  const _MemberItem({
    required this.member,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.systemGray6,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.person,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.staffName ?? '-',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                if (member.staffEmail != null)
                  Text(
                    member.staffEmail!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
              ],
            ),
          ),
          AppIconButton(
            icon: Icons.remove_circle_outline,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
