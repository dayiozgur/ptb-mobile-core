import 'package:supabase_flutter/supabase_flutter.dart';

import '../connectivity/connectivity_service.dart';
import '../connectivity/offline_sync_service.dart';
import '../di/service_locator.dart';
import '../tenant/tenant_service.dart';
import '../utils/logger.dart';

/// Offline kuyruğunda yorum-ekleme işlemleri için op-tipi anahtarı
/// (OfflineSyncService handler'ı bununla kayıtlanır ve tetiklenir).
const String kCommentCreateOpType = 'comment_create';

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
  ///
  /// OFFLINE: bağlantı yoksa yorum kuyruğa alınır ve iyimser (optimistic) bir
  /// [EntityComment] dönülür (UI'da hemen görünür, id geçici op-id'sidir).
  /// Online olunca OfflineSyncService kuyruğu boşaltıp [replayAddComment] ile
  /// gerçek insert'i oynatır. Online path DEĞİŞMEDİ.
  Future<EntityComment?> add(
    String entityType,
    String entityId,
    String content,
  ) async {
    final text = content.trim();
    if (text.isEmpty) return null;

    final sync = _offlineSyncOrNull;
    if (sync != null && (_connectivityOrNull?.isOffline ?? false)) {
      final op = await sync.addOperation(
        type: PendingOperationType.create,
        entityType: kCommentCreateOpType,
        entityId: entityId,
        data: {
          'entityType': entityType,
          'entityId': entityId,
          'content': text,
        },
      );
      Logger.info('Offline: comment queued (${op.id}, $entityType/$entityId)');
      return EntityComment(
        id: op.id,
        content: text,
        createdBy: _supabase.auth.currentUser?.id,
        authorName: 'Siz',
        createdAt: DateTime.now(),
      );
    }

    return _insertCommentToNetwork(entityType, entityId, text);
  }

  /// Gerçek ağ yazımı (`comments` INSERT). Online path burada; offline kuyruk
  /// replay'i de doğrudan bunu çağırır. Hata/boşta null döner (UI'a fırlatmaz).
  Future<EntityComment?> _insertCommentToNetwork(
    String entityType,
    String entityId,
    String text,
  ) async {
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

  /// Offline kuyruk replay handler'ı: kaydedilmiş payload ile yorum insert'ini
  /// yeniden oynatır. Başarıda `true` (kuyruktan silinir); insert null dönerse
  /// (RLS/ağ hatası) `false` → retry/dead-letter.
  ///
  /// Idempotency notu: `comments` INSERT kalıcı bir idempotency anahtarı
  /// taşımaz; ağ yazımı başarılı olup yanıt kaybolursa gecikmiş replay KOPYA
  /// yorum yaratabilir (nadir, zararsız). Birincil koruma kuyruğun başarı→sil
  /// davranışıdır.
  Future<bool> replayAddComment(PendingOperation op) async {
    final d = op.data;
    final r = await _insertCommentToNetwork(
      d['entityType'] as String,
      d['entityId'] as String,
      d['content'] as String,
    );
    return r != null;
  }

  // Offline-queue erişimi (kayıtlı/başlatılmamışsa null → add() doğrudan ağ
  // path'ine düşer, davranış değişmez).
  ConnectivityService? get _connectivityOrNull =>
      sl.isRegistered<ConnectivityService>() ? sl<ConnectivityService>() : null;

  OfflineSyncService? get _offlineSyncOrNull {
    if (!sl.isRegistered<OfflineSyncService>()) return null;
    final s = sl<OfflineSyncService>();
    return s.isInitialized ? s : null;
  }
}
