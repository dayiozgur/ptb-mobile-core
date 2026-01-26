import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Davet Servisi instance'ı
final invitationService = InvitationService(
  supabase: Supabase.instance.client,
);

/// İzin Servisi instance'ı
final permissionService = PermissionService(
  supabase: Supabase.instance.client,
  cacheManager: cacheManager,
);

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TenantMembership> _members = [];
  List<Invitation> _invitations = [];
  bool _isLoading = true;
  String? _error;
  bool _canInvite = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tenantId = tenantService.currentTenantId;
      final userId = authService.currentUser?.id;

      if (tenantId == null || userId == null) {
        setState(() {
          _error = 'Oturum bilgisi bulunamadı';
          _isLoading = false;
        });
        return;
      }

      // Paralel yükleme
      final results = await Future.wait([
        tenantService.getTenantMembers(tenantId),
        invitationService.getTenantInvitations(tenantId),
        permissionService.hasPermission(
          userId: userId,
          tenantId: tenantId,
          permission: 'users.create',
        ),
      ]);

      setState(() {
        _members = results[0] as List<TenantMembership>;
        _invitations = results[1] as List<Invitation>;
        _canInvite = results[2] as bool;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Failed to load members', e);
      setState(() {
        _error = 'Veriler yüklenemedi';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Üyeler',
      showBackButton: true,
      actions: [
        if (_canInvite)
          AppIconButton(
            icon: Icons.person_add,
            onPressed: _showInviteDialog,
          ),
      ],
      child: Column(
        children: [
          // Tab bar
          Container(
            color: AppColors.secondarySystemBackground(context),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.secondaryLabel(context),
              indicatorColor: AppColors.primary,
              tabs: [
                Tab(text: 'Üyeler (${_members.length})'),
                Tab(text: 'Davetler (${_invitations.where((i) => i.status == InvitationStatus.pending).length})'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: _isLoading
                ? const Center(child: AppLoadingIndicator())
                : _error != null
                    ? AppErrorView(
                        title: 'Hata',
                        message: _error!,
                        actionLabel: 'Tekrar Dene',
                        onAction: _loadData,
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildMembersList(),
                          _buildInvitationsList(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList() {
    if (_members.isEmpty) {
      return AppEmptyState(
        icon: Icons.people_outline,
        title: 'Henüz Üye Yok',
        message: 'Bu tenant\'ta henüz üye bulunmuyor.',
        actionLabel: _canInvite ? 'Davet Gönder' : null,
        onAction: _canInvite ? _showInviteDialog : null,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: AppSpacing.screenPadding,
        itemCount: _members.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final member = _members[index];
          return _MemberCard(
            membership: member,
            onRoleChange: _canInvite ? () => _showRoleChangeDialog(member) : null,
            onRemove: _canInvite ? () => _confirmRemoveMember(member) : null,
          );
        },
      ),
    );
  }

  Widget _buildInvitationsList() {
    final pendingInvitations =
        _invitations.where((i) => i.status == InvitationStatus.pending).toList();

    if (pendingInvitations.isEmpty) {
      return AppEmptyState(
        icon: Icons.mail_outline,
        title: 'Bekleyen Davet Yok',
        message: 'Tüm davetler yanıtlanmış veya süresi dolmuş.',
        actionLabel: _canInvite ? 'Yeni Davet Gönder' : null,
        onAction: _canInvite ? _showInviteDialog : null,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: AppSpacing.screenPadding,
        itemCount: pendingInvitations.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final invitation = pendingInvitations[index];
          return _InvitationCard(
            invitation: invitation,
            onResend: () => _resendInvitation(invitation),
            onCancel: () => _cancelInvitation(invitation),
          );
        },
      ),
    );
  }

  void _showInviteDialog() {
    final emailController = TextEditingController();
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    TenantRole selectedRole = TenantRole.member;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: AppBottomSheet(
            title: 'Kullanıcı Davet Et',
            child: Padding(
              padding: AppSpacing.screenPadding,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: emailController,
                      label: 'Email Adresi',
                      placeholder: 'ornek@email.com',
                      prefixIcon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.combine([
                        Validators.required('Email zorunludur'),
                        Validators.email('Geçerli bir email girin'),
                      ]),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Role selection
                    Text(
                      'Rol',
                      style: AppTypography.subheadline,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        TenantRole.member,
                        TenantRole.manager,
                        TenantRole.admin,
                      ].map((role) {
                        final isSelected = selectedRole == role;
                        return ChoiceChip(
                          label: Text(role.displayName),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() => selectedRole = role);
                            }
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      controller: messageController,
                      label: 'Mesaj (Opsiyonel)',
                      placeholder: 'Davet mesajı...',
                      prefixIcon: Icons.message,
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Davet Gönder',
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        final tenantId = tenantService.currentTenantId;
                        final userId = authService.currentUser?.id;
                        if (tenantId == null || userId == null) return;

                        try {
                          final invitation =
                              await invitationService.createInvitation(
                            email: emailController.text.trim(),
                            tenantId: tenantId,
                            invitedBy: userId,
                            role: selectedRole,
                            message: messageController.text.trim().isNotEmpty
                                ? messageController.text.trim()
                                : null,
                          );

                          if (context.mounted) {
                            Navigator.pop(context);

                            if (invitation != null) {
                              AppSnackbar.showSuccess(
                                context,
                                message: 'Davet gönderildi',
                              );
                              _loadData();
                            }
                          }
                        } on InvitationException catch (e) {
                          if (context.mounted) {
                            AppSnackbar.showError(context, message: e.message);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            AppSnackbar.showError(
                              context,
                              message: 'Davet gönderilemedi',
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRoleChangeDialog(TenantMembership member) {
    TenantRole selectedRole = member.role;

    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AppBottomSheet(
          title: 'Rol Değiştir',
          child: Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Yeni rol seçin:',
                  style: AppTypography.subheadline,
                ),
                const SizedBox(height: AppSpacing.md),
                ...TenantRole.values.where((r) => r != TenantRole.owner).map(
                  (role) => RadioListTile<TenantRole>(
                    title: Text(role.displayName),
                    subtitle: Text(_getRoleDescription(role)),
                    value: role,
                    groupValue: selectedRole,
                    onChanged: (value) {
                      if (value != null) {
                        setModalState(() => selectedRole = value);
                      }
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Kaydet',
                  onPressed: () async {
                    await tenantService.updateMemberRole(
                      membershipId: member.id,
                      newRole: selectedRole,
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                      AppSnackbar.showSuccess(
                        context,
                        message: 'Rol güncellendi',
                      );
                      _loadData();
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRoleDescription(TenantRole role) {
    switch (role) {
      case TenantRole.owner:
        return 'Tüm yetkilere sahip';
      case TenantRole.admin:
        return 'Faturalama hariç tüm yetkiler';
      case TenantRole.manager:
        return 'Operasyonel yönetim';
      case TenantRole.member:
        return 'Temel kullanıcı';
      case TenantRole.viewer:
        return 'Sadece görüntüleme';
    }
  }

  Future<void> _confirmRemoveMember(TenantMembership member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Üyeyi Kaldır'),
        content: const Text(
          'Bu kullanıcıyı tenant\'tan kaldırmak istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await tenantService.removeMember(member.id);
      if (mounted) {
        if (success) {
          AppSnackbar.showSuccess(context, message: 'Üye kaldırıldı');
          _loadData();
        } else {
          AppSnackbar.showError(context, message: 'Üye kaldırılamadı');
        }
      }
    }
  }

  Future<void> _resendInvitation(Invitation invitation) async {
    final userId = authService.currentUser?.id;
    if (userId == null) return;

    final newInvitation = await invitationService.resendInvitation(
      invitation.id,
      userId,
    );

    if (mounted) {
      if (newInvitation != null) {
        AppSnackbar.showSuccess(context, message: 'Davet yeniden gönderildi');
        _loadData();
      } else {
        AppSnackbar.showError(context, message: 'Davet gönderilemedi');
      }
    }
  }

  Future<void> _cancelInvitation(Invitation invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daveti İptal Et'),
        content: const Text(
          'Bu daveti iptal etmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('İptal Et'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      final success = await invitationService.cancelInvitation(
        invitation.id,
        userId,
      );

      if (mounted) {
        if (success) {
          AppSnackbar.showSuccess(context, message: 'Davet iptal edildi');
          _loadData();
        } else {
          AppSnackbar.showError(context, message: 'Davet iptal edilemedi');
        }
      }
    }
  }
}

class _MemberCard extends StatelessWidget {
  final TenantMembership membership;
  final VoidCallback? onRoleChange;
  final VoidCallback? onRemove;

  const _MemberCard({
    required this.membership,
    this.onRoleChange,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            AppAvatar(
              name: membership.userId,
              size: AppAvatarSize.medium,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    membership.userId.substring(0, 8),
                    style: AppTypography.headline,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  AppBadge(
                    label: membership.role.displayName,
                    variant: _getRoleBadgeVariant(membership.role),
                    size: AppBadgeSize.small,
                  ),
                ],
              ),
            ),
            if (onRoleChange != null || onRemove != null)
              PopupMenuButton<String>(
                itemBuilder: (context) => [
                  if (onRoleChange != null)
                    const PopupMenuItem(
                      value: 'role',
                      child: Text('Rol Değiştir'),
                    ),
                  if (onRemove != null)
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        'Kaldır',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
                onSelected: (value) {
                  if (value == 'role') onRoleChange?.call();
                  if (value == 'remove') onRemove?.call();
                },
              ),
          ],
        ),
      ),
    );
  }

  AppBadgeVariant _getRoleBadgeVariant(TenantRole role) {
    switch (role) {
      case TenantRole.owner:
        return AppBadgeVariant.warning;
      case TenantRole.admin:
        return AppBadgeVariant.error;
      case TenantRole.manager:
        return AppBadgeVariant.primary;
      case TenantRole.member:
        return AppBadgeVariant.info;
      case TenantRole.viewer:
        return AppBadgeVariant.secondary;
    }
  }
}

class _InvitationCard extends StatelessWidget {
  final Invitation invitation;
  final VoidCallback onResend;
  final VoidCallback onCancel;

  const _InvitationCard({
    required this.invitation,
    required this.onResend,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(
                  name: invitation.email,
                  size: AppAvatarSize.medium,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.email,
                        style: AppTypography.headline,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: [
                          AppBadge(
                            label: invitation.role.displayName,
                            variant: AppBadgeVariant.info,
                            size: AppBadgeSize.small,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          AppBadge(
                            label: '${invitation.remainingDays} gün kaldı',
                            variant: invitation.remainingDays <= 2
                                ? AppBadgeVariant.warning
                                : AppBadgeVariant.secondary,
                            size: AppBadgeSize.small,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'resend',
                      child: Text('Yeniden Gönder'),
                    ),
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text(
                        'İptal Et',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'resend') onResend();
                    if (value == 'cancel') onCancel();
                  },
                ),
              ],
            ),
            if (invitation.message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.tertiarySystemBackground(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.message_outlined,
                      size: 16,
                      color: AppColors.tertiaryLabel(context),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        invitation.message!,
                        style: AppTypography.caption1.copyWith(
                          color: AppColors.secondaryLabel(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
