import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';


/// Admin "Personel / Organizasyon" görüntüleyici (salt-okuma, v1).
///
/// Web portalının staff-roster / departman admin görünümlerini aynalar
/// (aynı Supabase projesi, [AdminStaffService] üzerinden). İki sekme:
/// **Personel** (arama + kart listesi; karta dokununca iletişim + istihdam
/// bilgisi alt-sayfası) ve **Departmanlar** (ad + kod + personel sayısı).
///
/// Tenant/organizasyon kapsamı RLS ile sağlanır; elde tenant varsa
/// [AdminStaffService] `tenant_id` ile daraltır.
///
/// KRİTİK: Kaydırma alanında sınırsız-yükseklikli Flex YOK — içerik
/// [ListView] ile çizilir.
class StaffRosterScreen extends StatefulWidget {
  const StaffRosterScreen({super.key});

  @override
  State<StaffRosterScreen> createState() => _StaffRosterScreenState();
}

class _StaffRosterScreenState extends State<StaffRosterScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;

  int _tabIndex = 0; // 0 = Personel, 1 = Departmanlar
  String _search = '';

  List<AdminStaffRow> _staff = [];
  List<AdminDepartmentRow> _departments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tenantId = sl<TenantService>().currentTenantId;
      final service = sl<AdminStaffService>();

      final staff = await service.listStaff(tenantId: tenantId);
      final departments = await service.listDepartments(tenantId: tenantId);

      if (mounted) {
        setState(() {
          _staff = staff;
          _departments = departments;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('StaffRosterScreen yükleme hatası', e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Kayıtlar yüklenemedi: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _search = value);
  }

  List<AdminStaffRow> get _filteredStaff {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _staff;
    return _staff.where((s) {
      return s.fullName.toLowerCase().contains(q) ||
          (s.email ?? '').toLowerCase().contains(q) ||
          (s.displayTitle ?? '').toLowerCase().contains(q) ||
          (s.departmentName ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<AdminDepartmentRow> get _filteredDepartments {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _departments;
    return _departments.where((d) {
      return (d.name ?? '').toLowerCase().contains(q) ||
          (d.code ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Personel',
      showBackButton: true,
      actions: [
        AppIconButton(
          icon: Icons.refresh,
          onPressed: _loadData,
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: AppSegmentedControl(
              segments: const ['Personel', 'Departmanlar'],
              selectedIndex: _tabIndex,
              onSegmentChanged: (i) => setState(() => _tabIndex = i),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: AppSearchField(
              controller: _searchController,
              placeholder: 'Ara',
              onChanged: _onSearchChanged,
              onClear: () => _onSearchChanged(''),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadData,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(
          message: _errorMessage!,
          onRetry: _loadData,
        ),
      );
    }

    return _tabIndex == 0 ? _buildStaffList() : _buildDepartmentList();
  }

  Widget _buildEmpty() {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: const Center(
            child: AppEmptyState(
              icon: Icons.people_outline,
              title: 'Kayıt yok',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaffList() {
    final items = _filteredStaff;
    if (items.isEmpty) return _buildEmpty();

    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final staff = items[index];
        return _StaffCard(
          staff: staff,
          onTap: () => _showStaffDetail(staff),
        );
      },
    );
  }

  Widget _buildDepartmentList() {
    final items = _filteredDepartments;
    if (items.isEmpty) return _buildEmpty();

    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final dept = items[index];
        return _DepartmentCard(department: dept);
      },
    );
  }

  void _showStaffDetail(AdminStaffRow staff) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StaffDetailSheet(staff: staff),
    );
  }
}

// ============================================
// PERSONEL KARTI
// ============================================

class _StaffCard extends StatelessWidget {
  final AdminStaffRow staff;
  final VoidCallback onTap;

  const _StaffCard({required this.staff, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = staff.displayTitle;
    final dept = staff.departmentName;
    final org = staff.organizationName;

    // Ünvan · Departman ikinci satır.
    final subtitleParts = <String>[
      if (title != null && title.isNotEmpty) title,
      if (dept != null && dept.isNotEmpty) dept,
    ];

    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            AppAvatar(name: staff.fullName),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    staff.fullName.isEmpty ? '—' : staff.fullName,
                    style: AppTypography.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitleParts.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitleParts.join(' · '),
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (org != null && org.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      org,
                      style: AppTypography.caption2.copyWith(
                        color: AppColors.tertiaryLabel(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

// ============================================
// DEPARTMAN KARTI
// ============================================

class _DepartmentCard extends StatelessWidget {
  final AdminDepartmentRow department;

  const _DepartmentCard({required this.department});

  @override
  Widget build(BuildContext context) {
    final code = department.code;
    final org = department.organizationName;

    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            const Icon(Icons.apartment_outlined),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    department.name?.trim().isNotEmpty == true
                        ? department.name!
                        : '—',
                    style: AppTypography.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((code != null && code.isNotEmpty) ||
                      (org != null && org.isNotEmpty)) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      [
                        if (code != null && code.isNotEmpty) code,
                        if (org != null && org.isNotEmpty) org,
                      ].join(' · '),
                      style: AppTypography.caption1.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppBadge(
              label: '${department.headcount}',
              variant: AppBadgeVariant.neutral,
              size: AppBadgeSize.small,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// DETAY ALT-SAYFASI (salt-okuma)
// ============================================

class _StaffDetailSheet extends StatelessWidget {
  final AdminStaffRow staff;

  const _StaffDetailSheet({required this.staff});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final maxH = MediaQuery.of(context).size.height * 0.85;

    final employment = <_DetailEntry>[
      _DetailEntry('Ünvan', staff.displayTitle),
      _DetailEntry('Departman', staff.departmentName),
      _DetailEntry('Organizasyon', staff.organizationName),
      _DetailEntry('Personel Kodu', staff.code),
    ];

    final contact = <_DetailEntry>[
      _DetailEntry('E-posta', staff.email),
      _DetailEntry('Telefon', staff.phone),
      _DetailEntry('Adres', staff.address),
      _DetailEntry('Şehir', staff.town),
    ];

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sürükleme tutamacı
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.systemGray4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                children: [
                  Row(
                    children: [
                      AppAvatar(
                        name: staff.fullName,
                        size: AppAvatarSize.large,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              staff.fullName.isEmpty ? '—' : staff.fullName,
                              style: AppTypography.title3,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (staff.displayTitle != null) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                staff.displayTitle!,
                                style: AppTypography.subhead.copyWith(
                                  color: AppColors.secondaryLabel(context),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _DetailSection(title: 'İstihdam', entries: employment),
                  const SizedBox(height: AppSpacing.md),
                  _DetailSection(title: 'İletişim', entries: contact),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailEntry {
  final String label;
  final String? value;

  const _DetailEntry(this.label, this.value);
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<_DetailEntry> entries;

  const _DetailSection({required this.title, required this.entries});

  @override
  Widget build(BuildContext context) {
    final visible =
        entries.where((e) => (e.value ?? '').trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTypography.footnote.copyWith(
            color: AppColors.secondaryLabel(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (visible.isEmpty)
          Text(
            '—',
            style: AppTypography.body.copyWith(
              color: AppColors.tertiaryLabel(context),
            ),
          )
        else
          ...visible.map((e) => _DetailRow(entry: e)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final _DetailEntry entry;

  const _DetailRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              entry.label,
              style: AppTypography.subhead.copyWith(
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              entry.value ?? '—',
              style: AppTypography.body,
            ),
          ),
        ],
      ),
    );
  }
}
