import 'package:flutter/material.dart';
import 'package:protoolbag_core/protoolbag_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// PHR (İK) kişisel-pano widget'larının veri-bağlı render tile'ları.
///
/// Web `ptb-page-widget` `*Data` fetch'leriyle aynı kaynakları (ESS RPC'leri +
/// `announcements`) tüketir; böylece `my-dashboard-hr` şablonundaki base
/// widget'lar gri kutu yerine gerçek veriyle görünür. Her tile kendi verisini
/// çeker (self-contained), [DynWidgetCard] içinde render eder.

const List<String> _trMonths = [
  'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
];

String _monthYear(int? y, int? m) {
  if (y == null || m == null || m < 1 || m > 12) return '';
  return '${_trMonths[m - 1]} $y';
}

String _money(num v) => '₺${v.toStringAsFixed(2)}';

String _dur(int minutes) {
  if (minutes <= 0) return '0dk';
  final h = minutes ~/ 60, mm = minutes % 60;
  if (h == 0) return '${mm}dk';
  if (mm == 0) return '${h}s';
  return '${h}s ${mm}dk';
}

/// Profil kartı — ad + rol · organizasyon + imzalı avatar.
class ProfileCardTile extends StatefulWidget {
  final DashboardWidgetDescriptor descriptor;
  const ProfileCardTile({super.key, required this.descriptor});
  @override
  State<ProfileCardTile> createState() => _ProfileCardTileState();
}

class _ProfileCardTileState extends State<ProfileCardTile> {
  UserProfile? _p;
  String? _avatar;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await sl<ProfileService>().getProfileBundle();
      String? avatar;
      if (p != null) {
        avatar = await sl<FileStorageService>().getAvatarUrl(p.avatarUrl);
      }
      if (!mounted) return;
      setState(() {
        _p = p;
        _avatar = avatar;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _subtitle(UserProfile p) {
    final role = _roleLabel(p.coarseRole);
    final tenant = (p.tenantName ?? '').trim();
    if (role.isNotEmpty && tenant.isNotEmpty) return '$role · $tenant';
    if (role.isNotEmpty) return role;
    if (tenant.isNotEmpty) return tenant;
    return p.email;
  }

  String _roleLabel(String? r) {
    switch (r) {
      case 'ROLE_ADMIN':
        return 'Yönetici';
      case 'ROLE_MANAGER':
        return 'Müdür';
      case 'ROLE_CUSTOMER':
        return 'Müşteri';
      case 'ROLE_USER':
        return 'Kullanıcı';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.descriptor.title ?? 'Profil Kartım';
    if (_loading) return DynWidgetCard(title: title, loading: true);
    final p = _p;
    final name = p?.displayName ?? '';
    final b = Theme.of(context).brightness;
    return DynWidgetCard(
      title: title,
      child: Row(
        children: [
          AppAvatar(
              imageUrl: _avatar,
              name: name.isEmpty ? 'U' : name,
              size: AppAvatarSize.large),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name.isEmpty ? '—' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.withColor(
                        AppTypography.headline, AppColors.textPrimary(b))),
                if (p != null) ...[
                  const SizedBox(height: 2),
                  Text(_subtitle(p),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.withColor(
                          AppTypography.footnote, AppColors.textSecondary(b))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// İzin bakiyesi — toplam kalan/hak edilen + tür kırılımı.
class LeaveBalanceTile extends StatefulWidget {
  final DashboardWidgetDescriptor descriptor;
  const LeaveBalanceTile({super.key, required this.descriptor});
  @override
  State<LeaveBalanceTile> createState() => _LeaveBalanceTileState();
}

class _LeaveBalanceTileState extends State<LeaveBalanceTile> {
  late Future<List<LeaveBalance>> _future;
  @override
  void initState() {
    super.initState();
    _future = sl<HrEssService>().leaveBalance();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.descriptor.title ?? 'İzin Bakiyem';
    final b = Theme.of(context).brightness;
    return FutureBuilder<List<LeaveBalance>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return DynWidgetCard(title: title, loading: true);
        }
        if (snap.hasError) {
          return DynWidgetCard(
              title: title,
              error: 'Yüklenemedi',
              onRetry: () => setState(
                  () => _future = sl<HrEssService>().leaveBalance()));
        }
        final rows = snap.data ?? const <LeaveBalance>[];
        final entitled = rows.fold<num>(0, (a, r) => a + r.entitled);
        final remaining = rows.fold<num>(0, (a, r) => a + r.remaining);
        final used = rows.fold<num>(0, (a, r) => a + r.used);
        final pct = entitled > 0 ? (used / entitled).clamp(0.0, 1.0) : 0.0;
        return DynWidgetCard(
          title: title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${remaining.round()}',
                      style: AppTypography.withColor(
                          AppTypography.title1, AppColors.primary)),
                  const SizedBox(width: 6),
                  Text('/ ${entitled.round()} gün kalan',
                      style: AppTypography.withColor(AppTypography.footnote,
                          AppColors.textSecondary(b))),
                ],
              ),
              if (entitled > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: pct.toDouble(), minHeight: 6),
                ),
              ],
              if (rows.isEmpty) ...[
                const SizedBox(height: 4),
                Text('İzin türü tanımlı değil',
                    style: AppTypography.withColor(
                        AppTypography.footnote, AppColors.textSecondary(b))),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Son maaş — net ödenecek + dönem.
class PayslipNetTile extends StatefulWidget {
  final DashboardWidgetDescriptor descriptor;
  const PayslipNetTile({super.key, required this.descriptor});
  @override
  State<PayslipNetTile> createState() => _PayslipNetTileState();
}

class _PayslipNetTileState extends State<PayslipNetTile> {
  late Future<List<Payslip>> _future;
  @override
  void initState() {
    super.initState();
    _future = sl<HrEssService>().myPayslips(limit: 1);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.descriptor.title ?? 'Son Maaşım';
    final b = Theme.of(context).brightness;
    return FutureBuilder<List<Payslip>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return DynWidgetCard(title: title, loading: true);
        }
        final list = snap.data ?? const <Payslip>[];
        if (snap.hasError || list.isEmpty) {
          return DynWidgetCard(
            title: title,
            child: Text('Bordro bulunamadı',
                style: AppTypography.withColor(
                    AppTypography.body, AppColors.textSecondary(b))),
          );
        }
        final p = list.first;
        return DynWidgetCard(
          title: title,
          subtitle: _monthYear(p.periodYear, p.periodMonth),
          child: Text(_money(p.netPayable),
              style: AppTypography.withColor(
                  AppTypography.title1, AppColors.success)),
        );
      },
    );
  }
}

/// Bugün (PDKS) — bugünkü çalışma/giriş-çıkış durumu.
class PdksTodayTile extends StatefulWidget {
  final DashboardWidgetDescriptor descriptor;
  const PdksTodayTile({super.key, required this.descriptor});
  @override
  State<PdksTodayTile> createState() => _PdksTodayTileState();
}

class _PdksTodayTileState extends State<PdksTodayTile> {
  late Future<List<PdksDay>> _future;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _future = sl<HrEssService>().pdksRange(today, today);
  }

  String _hhmm(DateTime? d) => d == null
      ? '--:--'
      : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final title = widget.descriptor.title ?? 'Bugün';
    final b = Theme.of(context).brightness;
    return FutureBuilder<List<PdksDay>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return DynWidgetCard(title: title, loading: true);
        }
        final list = snap.data ?? const <PdksDay>[];
        final day = list.isNotEmpty ? list.first : null;
        String status;
        if (day == null) {
          status = 'Kayıt yok';
        } else if (day.isHoliday) {
          status = 'Resmi tatil';
        } else if (day.isLeave) {
          status = 'İzinli';
        } else {
          status = '${_hhmm(day.entryTime)} - ${_hhmm(day.exitTime)}';
        }
        final worked = day?.workedMinutes ?? 0;
        return DynWidgetCard(
          title: title,
          child: Row(
            children: [
              Icon(Icons.schedule, size: 36, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(status,
                        style: AppTypography.withColor(AppTypography.headline,
                            AppColors.textPrimary(b))),
                    if (worked > 0) ...[
                      const SizedBox(height: 2),
                      Text('Çalışılan: ${_dur(worked)}',
                          style: AppTypography.withColor(AppTypography.footnote,
                              AppColors.textSecondary(b))),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Onay bekleyenler — yöneticinin bekleyen izin onay sayısı.
class PendingApprovalsTile extends StatefulWidget {
  final DashboardWidgetDescriptor descriptor;
  const PendingApprovalsTile({super.key, required this.descriptor});
  @override
  State<PendingApprovalsTile> createState() => _PendingApprovalsTileState();
}

class _PendingApprovalsTileState extends State<PendingApprovalsTile> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _future = sl<HrEssService>().pendingLeaveApprovals();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.descriptor.title ?? 'Onay Bekleyenler';
    final b = Theme.of(context).brightness;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return DynWidgetCard(title: title, loading: true);
        }
        final count = (snap.data ?? const []).length;
        final color = count > 0 ? AppColors.warning : AppColors.textSecondary(b);
        return DynWidgetCard(
          title: title,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text('$count',
                      style: AppTypography.withColor(
                          AppTypography.title2, color)),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                    count > 0 ? 'onay bekliyor' : 'Bekleyen onay yok',
                    style: AppTypography.withColor(
                        AppTypography.subhead, AppColors.textSecondary(b))),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Duyurular (news_feed) — yayınlanmış şirket duyuruları.
class NewsFeedTile extends StatefulWidget {
  final DashboardWidgetDescriptor descriptor;
  const NewsFeedTile({super.key, required this.descriptor});
  @override
  State<NewsFeedTile> createState() => _NewsFeedTileState();
}

class _NewsFeedTileState extends State<NewsFeedTile> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final limit = (widget.descriptor.config['limit'] as num?)?.toInt() ?? 5;
    var q = sl<SupabaseClient>()
        .from('announcements')
        .select('title, body, category, publish_date')
        .eq('published', true);
    final tid = sl<TenantService>().currentTenantId;
    if (tid != null) q = q.eq('tenant_id', tid);
    final res =
        await q.order('publish_date', ascending: false).limit(limit);
    return (res as List).cast<Map<String, dynamic>>();
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.descriptor.title ?? 'Duyurular';
    final b = Theme.of(context).brightness;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return DynWidgetCard(title: title, loading: true);
        }
        if (snap.hasError) {
          return DynWidgetCard(
              title: title,
              error: 'Yüklenemedi',
              onRetry: () => setState(() => _future = _fetch()));
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return DynWidgetCard(
            title: title,
            child: Text('Henüz duyuru yok',
                style: AppTypography.withColor(
                    AppTypography.footnote, AppColors.textSecondary(b))),
          );
        }
        return DynWidgetCard(
          title: title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: AppSpacing.md),
                Text(items[i]['title']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.withColor(
                        AppTypography.subhead, AppColors.textPrimary(b))),
                const SizedBox(height: 2),
                Text(
                  [
                    if ((items[i]['category']?.toString() ?? '').isNotEmpty)
                      items[i]['category'].toString(),
                    _fmtDate(items[i]['publish_date']?.toString()),
                  ].where((e) => e.isNotEmpty).join(' · '),
                  style: AppTypography.withColor(
                      AppTypography.caption1, AppColors.textSecondary(b)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Bağlantı kartı (link_card) — bir ekrana kısayol (config `{route,icon,color,description}`).
class LinkCardTile extends StatelessWidget {
  final DashboardWidgetDescriptor descriptor;
  const LinkCardTile({super.key, required this.descriptor});

  @override
  Widget build(BuildContext context) {
    final cfg = descriptor.config;
    final route = cfg['route']?.toString() ?? cfg['clickRoute']?.toString();
    final desc = cfg['description']?.toString() ?? descriptor.subtitle;
    final b = Theme.of(context).brightness;
    return DynWidgetCard(
      title: descriptor.title ?? 'Bağlantı',
      child: InkWell(
        onTap: (route == null || route.isEmpty || !ScreenResolver.hasScreen(route))
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ScreenResolver.resolve(
                    MenuItem(itemKey: '', title: descriptor.title ?? '', path: route)))),
        child: Row(
          children: [
            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(desc ?? (route ?? '—'),
                  style: AppTypography.withColor(
                      AppTypography.body, AppColors.textSecondary(b))),
            ),
          ],
        ),
      ),
    );
  }
}
