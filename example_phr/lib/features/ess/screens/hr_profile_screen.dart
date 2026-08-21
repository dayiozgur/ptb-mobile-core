import 'package:flutter/material.dart' hide FormField;
import 'package:go_router/go_router.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

import '../ess_common.dart';

/// Çalışanın kendi personel kaydı — "İK Profilim" (salt-okuma, `/hr/profile`).
///
/// Kimlik başlığı (avatar + ad + unvan) + İletişim / İstihdam / Kişisel bölüm
/// kartları; hassas blok (maaş / TC / IBAN / SGK / doğum tarihi) yalnızca
/// `fn_staff_personnel_get` çözülebildiğinde ayrı bir "Hassas Bilgiler" kartında
/// gösterilir. Web `MyProfileComponent` port'u.
class HrProfileScreen extends StatefulWidget {
  const HrProfileScreen({super.key});

  @override
  State<HrProfileScreen> createState() => _HrProfileScreenState();
}

class _HrProfileScreenState extends State<HrProfileScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  StaffProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final p = await hrProfileService.myStaffProfile();
      if (mounted) {
        setState(() {
          _profile = p;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Failed to load staff profile', e);
      if (mounted) {
        setState(() {
          _errorMessage = essT('common.data_load_error', 'Veriler yüklenemedi');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: essT('nav.phr_my_profile', 'İK Profilim'),
      onBack: () => context.pop(),
      actions: [
        AppIconButton(icon: Icons.refresh, onPressed: _load),
      ],
      child: RefreshIndicator(
        onRefresh: _load,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: AppLoadingIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(message: _errorMessage!, onRetry: _load),
      );
    }
    final p = _profile;
    if (p == null) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppEmptyState(
                icon: Icons.person_off_outlined,
                title: essT('hr.profile.no_staff_title', 'Personel kaydı yok'),
                message: essT('hr.profile.no_staff_message',
                    'Hesabınıza bağlı bir personel kaydı bulunamadı.'),
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: AppSpacing.screenPadding,
      children: [
        _header(context, p),
        const SizedBox(height: AppSpacing.md),
        _section(
          context,
          icon: Icons.badge_outlined,
          title: essT('hr.profile.section_employment', 'İstihdam'),
          rows: [
            _Row(essT('hr.profile.field_title', 'Unvan'), _txt(p.title)),
            _Row(essT('hr.profile.field_department', 'Departman'),
                _txt(p.departmentName)),
            _Row(essT('hr.profile.field_position', 'Pozisyon'),
                _txt(p.positionName)),
            _Row(essT('hr.profile.field_organization', 'Organizasyon'),
                _txt(p.organizationName)),
            _Row(essT('hr.profile.field_manager', 'Yönetici'),
                _txt(p.managerName)),
            _Row(essT('hr.profile.field_hire_date', 'İşe giriş'),
                p.hireDate != null ? essDate(p.hireDate) : '—'),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _section(
          context,
          icon: Icons.contact_mail_outlined,
          title: essT('hr.profile.section_contact', 'İletişim'),
          rows: [
            _Row(essT('hr.profile.field_email', 'E-posta'), _txt(p.email)),
            _Row(essT('hr.profile.field_phone', 'Telefon'), _txt(p.phone)),
            _Row(essT('hr.profile.field_address', 'Adres'), _txt(p.address)),
            _Row(essT('hr.profile.field_town', 'İlçe/Şehir'), _txt(p.town)),
            _Row(essT('hr.profile.field_emergency_name', 'Acil durum kişisi'),
                _txt(p.emergencyContactName)),
            _Row(essT('hr.profile.field_emergency_phone', 'Acil durum telefonu'),
                _txt(p.emergencyContactPhone)),
            _Row(
                essT('hr.profile.field_emergency_relation', 'Yakınlık'),
                _enumTxt(p.emergencyContactRelation, _relationMap)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _section(
          context,
          icon: Icons.person_outline,
          title: essT('hr.profile.section_personnel', 'Kişisel'),
          rows: [
            _Row(essT('hr.profile.field_gender', 'Cinsiyet'),
                _enumTxt(p.gender, _genderMap)),
            _Row(essT('hr.profile.field_marital_status', 'Medeni durum'),
                _enumTxt(p.maritalStatus, _maritalMap)),
            _Row(essT('hr.profile.field_blood_type', 'Kan grubu'),
                _txt(p.bloodType)),
            _Row(essT('hr.profile.field_education', 'Eğitim'),
                _enumTxt(p.educationLevel, _educationMap)),
            _Row(essT('hr.profile.field_military', 'Askerlik'),
                _enumTxt(p.militaryStatus, _militaryMap)),
          ],
        ),
        if (p.personnel != null) ...[
          const SizedBox(height: AppSpacing.md),
          _section(
            context,
            icon: Icons.lock_outline,
            title: essT('hr.profile.section_sensitive', 'Hassas Bilgiler'),
            rows: [
              _Row(
                essT('hr.profile.field_gross_salary', 'Brüt maaş'),
                p.personnel!.grossSalary != null
                    ? essMoney(p.personnel!.grossSalary!)
                    : '—',
              ),
              _Row(essT('hr.profile.field_tc', 'TC Kimlik No'),
                  _txt(p.personnel!.tcKimlikNo)),
              _Row(essT('hr.profile.field_iban', 'IBAN'),
                  _txt(p.personnel!.iban)),
              _Row(essT('hr.profile.field_sgk', 'SGK Sicil No'),
                  _txt(p.personnel!.sgkSicilNo)),
              _Row(
                essT('hr.profile.field_birth_date', 'Doğum tarihi'),
                p.personnel!.birthDate != null
                    ? essDate(p.personnel!.birthDate)
                    : '—',
              ),
            ],
            footnote: essT('hr.profile.sensitive_note',
                'Bu bilgiler yalnızca size görünür. Değişiklik için İK ile iletişime geçin.'),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _header(BuildContext context, StaffProfile p) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Row(
          children: [
            AppAvatar(name: p.displayName, size: AppAvatarSize.large),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.displayName, style: AppTypography.title3),
                  if (p.title != null && p.title!.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      p.title!,
                      style: AppTypography.subhead.copyWith(
                        color: AppColors.secondaryLabel(context),
                      ),
                    ),
                  ],
                  if (p.departmentName != null &&
                      p.departmentName!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.account_tree_outlined,
                            size: 14,
                            color: AppColors.tertiaryLabel(context)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            p.departmentName!,
                            style: AppTypography.caption1.copyWith(
                              color: AppColors.tertiaryLabel(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<_Row> rows,
    String? footnote,
  }) {
    return AppCard(
      child: Padding(
        padding: AppSpacing.cardInsets,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text(title, style: AppTypography.headline),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final r in rows) _detailRow(context, r),
            if (footnote != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                footnote,
                style: AppTypography.caption2.copyWith(
                  color: AppColors.tertiaryLabel(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, _Row r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              r.label,
              style: AppTypography.subhead.copyWith(
                color: AppColors.secondaryLabel(context),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              r.value,
              style: AppTypography.subhead,
            ),
          ),
        ],
      ),
    );
  }

  String _txt(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty ? '—' : s;
  }

  /// Kodlanmış enum değerini Türkçe etikete çevir (eşleşme yoksa ham değer).
  /// Web `MyProfileComponent` enum-map davranışının doğrudan Türkçe karşılığı.
  String _enumTxt(String? v, Map<String, String> map) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return '—';
    return map[raw.toLowerCase()] ?? raw;
  }

  static const Map<String, String> _genderMap = {
    'male': 'Erkek', 'erkek': 'Erkek',
    'female': 'Kadın', 'kadın': 'Kadın', 'kadin': 'Kadın',
    'other': 'Diğer', 'diğer': 'Diğer', 'diger': 'Diğer',
    'prefer_not': 'Belirtmek istemiyor',
  };
  static const Map<String, String> _maritalMap = {
    'single': 'Bekar', 'bekar': 'Bekar', 'bekâr': 'Bekar',
    'married': 'Evli', 'evli': 'Evli',
    'divorced': 'Boşanmış', 'boşanmış': 'Boşanmış', 'bosanmis': 'Boşanmış',
    'widowed': 'Dul', 'dul': 'Dul',
  };
  static const Map<String, String> _educationMap = {
    'primary': 'İlkokul', 'ilkokul': 'İlkokul',
    'secondary': 'Ortaokul', 'ortaokul': 'Ortaokul',
    'high_school': 'Lise', 'lise': 'Lise',
    'associate': 'Ön Lisans', 'önlisans': 'Ön Lisans',
    'onlisans': 'Ön Lisans', 'ön lisans': 'Ön Lisans',
    'bachelor': 'Lisans', 'lisans': 'Lisans',
    'master': 'Yüksek Lisans', 'yüksek lisans': 'Yüksek Lisans',
    'yuksek lisans': 'Yüksek Lisans',
    'phd': 'Doktora', 'doktora': 'Doktora',
  };
  static const Map<String, String> _militaryMap = {
    'done': 'Yapıldı', 'yapıldı': 'Yapıldı', 'yapildi': 'Yapıldı',
    'exempt': 'Muaf', 'muaf': 'Muaf',
    'deferred': 'Tecilli', 'tecilli': 'Tecilli', 'tecil': 'Tecilli',
    'not_applicable': 'Uygulanamaz',
  };
  static const Map<String, String> _relationMap = {
    'spouse': 'Eş', 'eş': 'Eş', 'es': 'Eş',
    'mother': 'Anne', 'anne': 'Anne',
    'father': 'Baba', 'baba': 'Baba',
    'sibling': 'Kardeş', 'kardeş': 'Kardeş', 'kardes': 'Kardeş',
    'child': 'Çocuk', 'çocuk': 'Çocuk', 'cocuk': 'Çocuk',
  };
}

/// Etiket/değer ikilisi (bölüm kartı satırı).
class _Row {
  final String label;
  final String value;
  const _Row(this.label, this.value);
}
