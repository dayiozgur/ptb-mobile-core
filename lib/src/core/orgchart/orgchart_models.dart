/// Org-chart ağaç düğümü — organizasyon VEYA departman (jenerik).
///
/// [children] alt-birimler (org: `parent_organization_id`, departman:
/// `parent_id`); [members] bu birime doğrudan bağlı personel.
class OrgTreeNode {
  final String id;
  final String name;
  final List<OrgTreeNode> children;
  final List<OrgMember> members;

  OrgTreeNode({
    required this.id,
    required this.name,
    List<OrgTreeNode>? children,
    List<OrgMember>? members,
  })  : children = children ?? [],
        members = members ?? [];

  /// Bu düğüm + tüm alt-ağacındaki toplam personel sayısı.
  int get totalMembers =>
      members.length +
      children.fold<int>(0, (sum, c) => sum + c.totalMembers);
}

/// Org-chart'ta bir personel (yaprak).
class OrgMember {
  final String id;
  final String name;
  final String? title;

  const OrgMember({required this.id, required this.name, this.title});
}
