import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// Admin — RBAC rol görüntüleyici (salt-okuma) servis.
///
/// Web portal `PtbRbacService.getRoles()` okuma-yolunu birebir aynalar
/// (aynı Supabase projesi). Yazma YOK — v1 salt-okuma viewer. Rol atama/CRUD
/// mobilde sunulmaz (web'de `rbac_user_roles`/`rbac_role_permissions` üzerine
/// çok-adımlı yazma ile yapılır).
///
/// Kaynak tablolar:
///  - `rbac_roles` — rol tanımları (code/name/description/level/color/icon).
///  - `rbac_role_platform_labels` — platforma özel, kiracıya-göre özelleştirilen
///    görünen ad (`label_i18n` jsonb: {tr, en}). Web bu tabloyu rol adını
///    platform bağlamında yeniden etiketlemek için kullanır (ör. PHR'de
///    "technician" → "Çalışan").
///
/// Tenant kapsamı **RLS** ile sağlanır; sistem rolleri (tenant-nötr) + kiracının
/// kendi rolleri döner. `active=true` filtresi + `level` azalan sıralama web ile
/// aynıdır.
class AdminRbacService {
  final SupabaseClient _supabase;

  AdminRbacService({required SupabaseClient supabase}) : _supabase = supabase;

  /// Rolleri (aktif) getirir. Web `PtbRbacService.getRoles` select'inin aynası
  /// (`select('*')` + `active=true` + `order('level', desc)`). RLS-scoped.
  Future<List<AdminRbacRole>> listRoles() async {
    try {
      final rows = await _supabase
          .from('rbac_roles')
          .select('*')
          .eq('active', true)
          .order('level', ascending: false);

      final result = (rows as List)
          .map((e) => AdminRbacRole.fromJson(e as Map<String, dynamic>))
          .toList();

      Logger.debug('AdminRbacService.listRoles → ${result.length} kayıt');
      return result;
    } catch (e, st) {
      Logger.error('AdminRbacService.listRoles hata', e, st);
      rethrow;
    }
  }

  /// Rol platform etiketleri: `role_code` → görünen ad (kiracı/platform
  /// özelleştirmesi). [platformId] verilirse yalnız o platformun etiketleri
  /// döner. `label_i18n` jsonb'sinden tr → en → `label_key` önceliğiyle çözülür.
  /// Etiket yoksa boş harita döner (rol adı ham `name` ile gösterilir).
  Future<Map<String, String>> listRoleLabels({String? platformId}) async {
    try {
      var query = _supabase
          .from('rbac_role_platform_labels')
          .select('role_code,label_key,label_i18n,platform_id')
          .eq('active', true);
      if (platformId != null && platformId.isNotEmpty) {
        query = query.eq('platform_id', platformId);
      }

      final rows = await query as List;
      final map = <String, String>{};
      for (final r in rows) {
        final m = r as Map<String, dynamic>;
        final code = m['role_code'] as String?;
        if (code == null || code.isEmpty) continue;
        final label = _resolveLabel(m);
        if (label != null && label.isNotEmpty) map[code] = label;
      }
      return map;
    } catch (e) {
      // Etiketler non-fatal — rol adı fallback olarak kullanılır.
      Logger.warning('AdminRbacService.listRoleLabels hata: $e');
      return const {};
    }
  }

  /// `label_i18n` jsonb'sinden en iyi görünen adı çöz (tr → en → label_key).
  static String? _resolveLabel(Map<String, dynamic> row) {
    final i18n = row['label_i18n'];
    if (i18n is Map) {
      final tr = i18n['tr'];
      if (tr is String && tr.isNotEmpty) return tr;
      final en = i18n['en'];
      if (en is String && en.isNotEmpty) return en;
    }
    final key = row['label_key'];
    if (key is String && key.isNotEmpty) return key;
    return null;
  }
}

/// RBAC rol satırı görüntü-modeli (salt-okuma).
class AdminRbacRole {
  final String id;
  final String code;
  final String name;
  final String? description;

  /// Yetki seviyesi (yüksek = daha güçlü; super_admin ≥ 100).
  final int level;

  /// Rozet rengi (hex, ör. `#DC2626`) — DB'de tanımlıysa.
  final String? color;

  /// Bootstrap ikon adı (ör. `bi-shield`) — bilgi amaçlı.
  final String? icon;
  final bool isSystem;
  final bool isExternal;

  const AdminRbacRole({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.level = 0,
    this.color,
    this.icon,
    this.isSystem = false,
    this.isExternal = false,
  });

  factory AdminRbacRole.fromJson(Map<String, dynamic> json) {
    return AdminRbacRole(
      id: json['id'] as String,
      code: (json['code'] as String?) ?? '',
      name: (json['name'] as String?) ?? (json['code'] as String?) ?? '',
      description: json['description'] as String?,
      level: (json['level'] as num?)?.toInt() ?? 0,
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      isSystem: json['is_system'] as bool? ?? false,
      isExternal: json['is_external'] as bool? ?? false,
    );
  }
}
