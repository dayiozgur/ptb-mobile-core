import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

/// **Organizasyon Şeması** — organizasyon ve departman hiyerarşisini
/// genişletilebilir ağaç olarak gösterir (web org-chart mobil karşılığı).
/// Toggle ile Organizasyon (`parent_organization_id`) ↔ Departman (`parent_id`)
/// ağacı arası geçiş; her düğümde alt-birimler + personel. Salt-okuma.
class OrgChartScreen extends StatefulWidget {
  const OrgChartScreen({super.key});

  @override
  State<OrgChartScreen> createState() => _OrgChartScreenState();
}

class _OrgChartScreenState extends State<OrgChartScreen> {
  final _ctrl = AsyncViewController();
  int _mode = 0; // 0 = organizasyon, 1 = departman

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Organizasyon Şeması',
      showBackButton: true,
      onBack: () => Navigator.of(context).maybePop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _ctrl.reload),
      ],
      child: Column(
        children: [
          Padding(
            padding: AppSpacing.screenPadding,
            child: AppSegmentedControl(
              segments: const ['Organizasyon', 'Departman'],
              selectedIndex: _mode,
              onSegmentChanged: (i) {
                if (i == _mode) return;
                setState(() => _mode = i);
                _ctrl.reload();
              },
            ),
          ),
          Expanded(
            child: AsyncView<List<OrgTreeNode>>(
              controller: _ctrl,
              load: () => _mode == 0
                  ? orgChartService.organizationTree()
                  : orgChartService.departmentTree(),
              errorFallback: 'Şema yüklenemedi',
              isEmpty: (d) => d.isEmpty,
              emptyBuilder: (context) => Center(
                child: AppEmptyState(
                  icon: Icons.account_tree_outlined,
                  title: _mode == 0
                      ? 'Organizasyon tanımlı değil'
                      : 'Departman tanımlı değil',
                ),
              ),
              builder: (context, roots) => ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                children: [
                  for (final n in roots) _OrgNodeTile(node: n, depth: 0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrgNodeTile extends StatelessWidget {
  final OrgTreeNode node;
  final int depth;

  const _OrgNodeTile({required this.node, required this.depth});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Theme(
      // ExpansionTile bölme çizgilerini gizle (temiz ağaç görünümü).
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: depth == 0,
        tilePadding: EdgeInsets.only(left: 16.0 + depth * 14, right: 16),
        childrenPadding: EdgeInsets.zero,
        leading: Icon(
          depth == 0 ? Icons.business_outlined : Icons.account_tree_outlined,
          color: AppColors.primary,
          size: 20,
        ),
        title: Text(
          node.name,
          style: AppTypography.subhead.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary(brightness),
          ),
        ),
        subtitle: Text(
          '${node.totalMembers} kişi'
          '${node.children.isNotEmpty ? ' · ${node.children.length} alt-birim' : ''}',
          style: AppTypography.caption1
              .copyWith(color: AppColors.textSecondary(brightness)),
        ),
        children: [
          for (final c in node.children)
            _OrgNodeTile(node: c, depth: depth + 1),
          for (final m in node.members)
            _MemberTile(member: m, depth: depth + 1),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final OrgMember member;
  final int depth;

  const _MemberTile({required this.member, required this.depth});

  String get _initials {
    final parts = member.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: EdgeInsets.only(
          left: 16.0 + (depth + 1) * 14, right: 16, top: 2, bottom: 2),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              _initials,
              style: AppTypography.caption2.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: AppTypography.footnote.copyWith(
                    color: AppColors.textPrimary(brightness),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if ((member.title ?? '').isNotEmpty)
                  Text(
                    member.title!,
                    style: AppTypography.caption2.copyWith(
                      color: AppColors.textSecondary(brightness),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
