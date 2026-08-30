import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/logger.dart';

/// One external file (OneDrive / SharePoint) linked to a CRM entity, from
/// `public.entity_file_links`. Mirrors the web model.
class EntityFileLink {
  final String id;
  final String name;
  final String webUrl;
  final String? source;
  final int? size;
  final String? mime;

  const EntityFileLink({
    required this.id,
    required this.name,
    required this.webUrl,
    this.source,
    this.size,
    this.mime,
  });

  factory EntityFileLink.fromMap(Map<String, dynamic> m) => EntityFileLink(
        id: m['id'] as String,
        name: (m['name'] ?? '') as String,
        webUrl: (m['web_url'] ?? '') as String,
        source: m['source'] as String?,
        size: (m['size'] as num?)?.toInt(),
        mime: m['mime'] as String?,
      );
}

/// CRUD over `public.entity_file_links` — the tenant-scoped association between
/// a CRM entity and a file that lives in the user's Microsoft drive. RLS
/// enforces the tenant; `tenant_id`/`created_by`/`provider` carry DB-side
/// defaults, so the client never supplies them.
class EntityFileLinkService {
  final SupabaseClient _supabase;
  EntityFileLinkService({required SupabaseClient supabase}) : _supabase = supabase;

  static const String _select = 'id,name,web_url,source,size,mime,created_at';

  Future<List<EntityFileLink>> list(String entityType, String entityId) async {
    try {
      final rows = await _supabase
          .from('entity_file_links')
          .select(_select)
          .eq('entity_type', entityType)
          .eq('entity_id', entityId)
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) => EntityFileLink.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      Logger.error('[file-links] list failed', e);
      return const <EntityFileLink>[];
    }
  }

  Future<EntityFileLink?> add({
    required String entityType,
    required String entityId,
    required String source,
    required String name,
    required String webUrl,
    String? itemId,
    String? driveId,
    int? size,
    String? mime,
  }) async {
    try {
      final row = await _supabase
          .from('entity_file_links')
          .insert(<String, dynamic>{
            'entity_type': entityType,
            'entity_id': entityId,
            'source': source,
            'name': name,
            'web_url': webUrl,
            'item_id': itemId,
            'drive_id': driveId,
            'size': size,
            'mime': mime,
          })
          .select(_select)
          .single();
      return EntityFileLink.fromMap(Map<String, dynamic>.from(row));
    } catch (e) {
      Logger.error('[file-links] add failed', e);
      return null;
    }
  }

  Future<bool> remove(String id) async {
    try {
      await _supabase.from('entity_file_links').delete().eq('id', id);
      return true;
    } catch (e) {
      Logger.error('[file-links] remove failed', e);
      return false;
    }
  }
}
