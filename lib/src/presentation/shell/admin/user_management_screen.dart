import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../../core/admin/admin_user_service.dart';

/// Admin — Kullanıcı Yönetimi ekranı.
///
/// Web portal `admin-management` user-management özelliğinin mobil karşılığı.
/// [AdminUserService] üzerinden tenant'ın kullanıcılarını (RLS-scoped) listeler;
/// ad/email ile arama yapılır. Her satır coarse role göre renklendirilmiş bir
/// rozet taşır (profil hub paleti: yönetici kırmızı, müdür amber, kullanıcı
/// yeşil, müşteri mavi). Satıra dokununca detay bottom-sheet açılır.
///
/// SALT-OKUNUR: web'de rol atama tek RPC değil, `rbac_user_roles` tablosuna
/// çok-adımlı yazma ile yapıldığından mobilde rol değiştirme sunulmaz.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _searchController = TextEditingController();

  List<UserProfile> _all = [];
  List<UserProfile> _filtered = [];
  final Map<String, String?> _avatarUrls = {};

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilter);
    _load();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applyFilter);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await sl<AdminUserService>().listUsers();
      if (!mounted) return;
      setState(() {
        _all = users;
        _loading = false;
      });
      _applyFilter();
      _resolveAvatars(users);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Kullanıcılar yüklenemedi';
        _loading = false;
      });
    }
  }

  /// Ham avatar path'lerini signed URL'e çöz (protected-bucket 404 önlemi).
  Future<void> _resolveAvatars(List<UserProfile> users) async {
    for (final u in users) {
      if (u.avatarUrl == null || u.avatarUrl!.isEmpty) continue;
      try {
        final url = await fileStorageService.getAvatarUrl(u.avatarUrl);
        if (!mounted) return;
        if (url != null) setState(() => _avatarUrls[u.id] = url);
      } catch (_) {
        // Avatar çözümü non-fatal — initials fallback devreye girer.
      }
    }
  }

  void _applyFilter() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = List.of(_all);
      } else {
        _filtered = _all.where((u) {
          final name = u.displayName.toLowerCase();
          final email = u.email.toLowerCase();
          return name.contains(q) || email.contains(q);
        }).toList();
      }
    });
  }

  // ── Coarse-role palette (profil hub ile birebir) ──────────────────────────

  Color _roleColor(String? role) {
    switch (role) {
      case 'ROLE_ADMIN':
        return const Color(0xFFDC2626); // kırmızı
      case 'ROLE_MANAGER':
        return const Color(0xFFD97706); // amber
      case 'ROLE_CUSTOMER':
        return const Color(0xFF2563EB); // mavi
      default:
        return const Color(0xFF059669); // yeşil (ROLE_USER)
    }
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'ROLE_ADMIN':
        return 'Yönetici';
      case 'ROLE_MANAGER':
        return 'Müdür';
      case 'ROLE_CUSTOMER':
        return 'Müşteri';
      default:
        return 'Kullanıcı';
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Kullanıcı Yönetimi',
      showBackButton: true,
      child: Column(
        children: [
          _buildSearchField(context),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Ara',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchController.clear(),
                ),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildMessage(context, Icons.error_outline, _error!, retry: true);
    }
    if (_filtered.isEmpty) {
      return _buildMessage(context, Icons.people_outline, 'Kullanıcı bulunamadı');
    }

    // CRITICAL: ListView (bounded) — kaydırma içinde unbounded Flex YOK.
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        itemCount: _filtered.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 72,
          color: AppColors.separator(context),
        ),
        itemBuilder: (context, i) => _buildUserTile(context, _filtered[i]),
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, UserProfile u) {
    final color = _roleColor(u.coarseRole);
    return ListTile(
      onTap: () => _showUserSheet(context, u),
      leading: AppAvatar(
        name: u.displayName,
        imageUrl: _avatarUrls[u.id],
        size: AppAvatarSize.medium,
      ),
      title: Text(
        u.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: u.email.isEmpty
          ? null
          : Text(
              u.email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.footnote
                  .copyWith(color: AppColors.secondaryLabel(context)),
            ),
      trailing: _roleChip(color, _roleLabel(u.coarseRole)),
    );
  }

  Widget _roleChip(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: AppTypography.caption1
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ── Detay bottom-sheet (salt-okunur) ──────────────────────────────────────

  void _showUserSheet(BuildContext context, UserProfile u) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(Theme.of(context).brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final color = _roleColor(u.coarseRole);
        // ListView: bottom-sheet içeriği için bounded, güvenli kaydırma.
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Center(
                child: AppAvatar(
                  name: u.displayName,
                  imageUrl: _avatarUrls[u.id],
                  size: AppAvatarSize.xl,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  u.displayName,
                  textAlign: TextAlign.center,
                  style: AppTypography.title3
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (u.email.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxs),
                Center(
                  child: Text(
                    u.email,
                    textAlign: TextAlign.center,
                    style: AppTypography.footnote
                        .copyWith(color: AppColors.secondaryLabel(ctx)),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Center(child: _roleChip(color, _roleLabel(u.coarseRole))),
              const SizedBox(height: AppSpacing.lg),
              _infoRow(ctx, Icons.badge_outlined, 'Rol',
                  _roleLabel(u.coarseRole)),
              _infoRow(
                ctx,
                u.active ? Icons.check_circle_outline : Icons.block,
                'Durum',
                u.active ? 'Aktif' : 'Pasif',
              ),
              if (u.username != null && u.username!.isNotEmpty)
                _infoRow(ctx, Icons.alternate_email, 'Kullanıcı adı',
                    u.username!),
              if (u.hasPhone)
                _infoRow(ctx, Icons.phone_outlined, 'Telefon', u.phone!),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.secondaryLabel(context)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$label: ',
            style: AppTypography.subhead
                .copyWith(color: AppColors.secondaryLabel(context)),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.subhead
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(BuildContext context, IconData icon, String message,
      {bool retry = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.secondaryLabel(context)),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            style: AppTypography.body
                .copyWith(color: AppColors.secondaryLabel(context)),
          ),
          if (retry) ...[
            const SizedBox(height: AppSpacing.md),
            TextButton(onPressed: _load, child: const Text('Tekrar dene')),
          ],
        ],
      ),
    );
  }
}
