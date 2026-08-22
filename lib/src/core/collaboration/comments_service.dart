import 'package:supabase_flutter/supabase_flutter.dart';

import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';

/// Bir entity'ye ait tek yorum (`public.comments` satırı).
class EntityComment {
  final String id;
  final String content;
  final String? createdBy;
  final String authorName;
  final DateTime? createdAt;

  const EntityComment({
    required this.id,
    required this.content,
    this.createdBy,
    this.authorName = '—',
    this.createdAt,
  });
}

/// **Generic yorum/tartışma servisi** — herhangi bir entity kaydına
/// (`entity_type` + `entity_id`) yorum listeler/ekler. CRM aktiviteleri, PPM
/// issue tartışmaları ve tüm entity-engine tipleri için ortak primitif.
///
/// `public.comments` tenant-scoped RLS (`tenant_id = get_my_tenant_id()`);
/// insert'te tenant_id + created_by set edilir. Hata durumunda boş döner /
/// null (UI'a fırlatmaz).
class CommentsService {
  final SupabaseClient _supabase;

  CommentsService({required SupabaseClient supabase}) : _supabase = supabase;

  TenantService get _tenant => sl<TenantService>();

  /// Bir entity'nin yorumları (eskiden yeniye). Yazar adları toplu çözülür.
  Future<List<EntityComment>> list(String entityType, String entityId) async {
    try {
      final res = await _supabase
          .from('comments')
          .select('id, content, created_by, created_at')
          .eq('entity_type', entityType)
          .eq('entity_id', entityId)
          .or('active.is.null,active.eq.true')
          .order('created_at', ascending: true);
      final rows = (res as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return [];

      // Yazar adlarını toplu çöz (profiles).
      final ids = rows
          .map((r) => r['created_by'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      final names = <String, String>{};
      if (ids.isNotEmpty) {
        try {
          final profs = await _supabase
              .from('profiles')
              .select('id, first_name, last_name, email')
              .inFilter('id', ids);
          for (final p in (profs as List).cast<Map<String, dynamic>>()) {
            final n = [p['first_name'], p['last_name']]
                .whereType<String>()
                .where((s) => s.isNotEmpty)
                .join(' ');
            names[p['id'] as String] =
                n.isNotEmpty ? n : (p['email'] as String? ?? '—');
          }
        } catch (_) {/* isim çözülemezse '—' */}
      }

      return rows
          .map((r) => EntityComment(
                id: r['id'] as String,
                content: r['content'] as String? ?? '',
                createdBy: r['created_by'] as String?,
                authorName: names[r['created_by']] ?? '—',
                createdAt: r['created_at'] != null
                    ? DateTime.tryParse(r['created_at'].toString())
                    : null,
              ))
          .toList();
    } catch (e) {
      Logger.error('comments list ($entityType/$entityId) hata', e);
      return [];
    }
  }

  /// Yorum ekle. Başarılıysa eklenen yorumu döner (yoksa null).
  Future<EntityComment?> add(
    String entityType,
    String entityId,
    String content,
  ) async {
    final text = content.trim();
    if (text.isEmpty) return null;
    try {
      final uid = _supabase.auth.currentUser?.id;
      final res = await _supabase
          .from('comments')
          .insert({
            'tenant_id': _tenant.currentTenantId,
            'entity_type': entityType,
            'entity_id': entityId,
            'content': text,
            'active': true,
            'created_by': uid,
            'updated_by': uid,
          })
          .select('id, content, created_by, created_at')
          .single();
      final map = Map<String, dynamic>.from(res);
      return EntityComment(
        id: map['id'] as String,
        content: map['content'] as String? ?? text,
        createdBy: map['created_by'] as String?,
        authorName: 'Siz',
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'].toString())
            : DateTime.now(),
      );
    } catch (e) {
      Logger.error('comment add ($entityType/$entityId) hata', e);
      return null;
    }
  }
}
