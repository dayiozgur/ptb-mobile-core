/// Organizasyon kırılımı (headcount rollup) satırı — salt-okuma.
///
/// Canlı şemada özel bir rollup RPC bulunmadığından (`org_rollup`/`fn_org…`
/// grep boş döndü), servis `staffs` satırlarını `organization_id` üzerinden
/// sayıp `organizations(name)` ile birleştirerek hesaplar. Her organizasyon
/// (0 personel dahil) bir satır olur.
class OrgRollupRow {
  final String organizationId;
  final String? organizationName;

  /// Bu organizasyona bağlı aktif personel sayısı.
  final int headcount;

  const OrgRollupRow({
    required this.organizationId,
    this.organizationName,
    this.headcount = 0,
  });
}
