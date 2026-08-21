import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../../../core/admin/admin_rbac_service.dart';

/// Admin — Roller (RBAC) görüntüleyici ekranı.
///
/// Web portal `admin-management` RBAC rol yönetimi özelliğinin mobil, salt-okuma
/// karşılığı. [AdminRbacService] üzerinden tenant'ın rollerini (RLS-scoped,
/// `level` azalan) listeler. Etkin platformda kiracıya-özel bir görünen ad
/// (`rbac_role_platform_labels`) tanımlıysa rol adının altında gösterilir.
///
/// SALT-OKUNUR: rol/izin atama mobilde sunulmaz (web'de çok-adımlı yazma).
class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  List<AdminRbacRole> _roles = [];
  Map<String, String> _labels = const {};

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = sl<AdminRbacService>();
      final roles = await svc.listRoles();
      // Etkin platformun rol etiketleri (non-fatal; boş dönebilir).
      final labels =
          await svc.listRoleLabels(platformId: platformContext.activePlatformId);
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _labels = labels;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Roller yüklenemedi';
        _loading = false;
      });
    }
  }

  // ── Renk paleti ─────────────────────────────────────────────────────────────

  /// Rol rengi: DB `color` (hex) geçerliyse onu kullan; değilse seviyeye göre
  /// profil-hub paletinden türet (yönetici kırmızı → gözlemci gri).
  Color _roleColor(AdminRbacRole role) {
    final parsed = _parseHex(role.color);
    if (parsed != null) return parsed;
    final level = role.level;
    if (level >= 100) return const Color(0xFF7C3AED); // mor — süper yönetici
    if (level >= 80) return const Color(0xFFDC2626); // kırmızı — yönetici
    if (level >= 50) return const Color(0xFFD97706); // amber — müdür/dispatcher
    if (level >= 20) return const Color(0xFF059669); // yeşil — kullanıcı
    return const Color(0xFF2563EB); // mavi — gözlemci/dış
  }

  static Color? _parseHex(String? hex) {
    if (hex == null) return null;
    var h = hex.trim();
    if (h.isEmpty) return null;
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final val = int.tryParse(h, radix: 16);
    if (val == null) return null;
    return Color(val);
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Roller',
      showBackButton: true,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _buildMessage(context, Icons.error_outline, _error!, retry: true);
    }
    if (_roles.isEmpty) {
      return _buildMessage(context, Icons.badge_outlined, 'Rol bulunamadı');
    }

    // CRITICAL: ListView (bounded) — kaydırma içinde unbounded Flex YOK.
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _roles.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) => _buildRoleCard(context, _roles[i]),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, AdminRbacRole role) {
    final color = _roleColor(role);
    final label = _labels[role.code];
    final desc = role.description?.trim();

    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      role.name,
                      style: AppTypography.body
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (label != null && label != role.name) ...[
                      const SizedBox(height: 2),
                      Text(
                        // Kiracı/platform özelleştirilmiş görünen ad.
                        label,
                        style: AppTypography.footnote.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _levelChip(color, role.level),
            ],
          ),
          if (desc != null && desc.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              desc,
              style: AppTypography.footnote
                  .copyWith(color: AppColors.secondaryLabel(context)),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _codeTag(context, role.code),
              if (role.isSystem) ...[
                const SizedBox(width: AppSpacing.xs),
                _flagTag(context, 'Sistem'),
              ],
              if (role.isExternal) ...[
                const SizedBox(width: AppSpacing.xs),
                _flagTag(context, 'Dış'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _levelChip(Color color, int level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Seviye $level',
        style: AppTypography.caption1
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _codeTag(BuildContext context, String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.secondaryLabel(context).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        code,
        style: AppTypography.caption1
            .copyWith(color: AppColors.secondaryLabel(context)),
      ),
    );
  }

  Widget _flagTag(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.secondaryLabel(context).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppTypography.caption1
            .copyWith(color: AppColors.secondaryLabel(context)),
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
