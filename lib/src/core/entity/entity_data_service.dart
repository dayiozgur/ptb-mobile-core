import 'package:supabase_flutter/supabase_flutter.dart';

import '../connectivity/connectivity_service.dart';
import '../connectivity/offline_sync_service.dart';
import '../di/service_locator.dart';
import '../platform/platform_context.dart';
import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'models/entity_type_config.dart';
import 'models/generic_entity.dart';

/// Offline kuyruğunda entity form-submit işlemleri için op-tipi anahtarı
/// (OfflineSyncService handler'ı bununla kayıtlanır ve tetiklenir).
const String kEntitySubmitOpType = 'entity_submit';

/// Entity Data Service
///
/// Dinamik entity kayıtlarını (`form_submissions` ya da bağlı tablolar)
/// listeler, tekil olarak getirir ve `form-submit` Edge Function üzerinden
/// kaydeder. Değerler alan tipine göre `form_field_values` kolonlarına
/// map'lenir / geri map'lenir.
class EntityDataService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  String? _currentTenantId;

  EntityDataService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  /// Tenant context'ini ayarla.
  void setTenant(String tenantId) {
    _currentTenantId = tenantId;
  }

  /// Context'i temizle.
  void clearContext() {
    _currentTenantId = null;
  }

  /// Aktif platformId (in-app platform switch). Platform izolasyonu (Tranche 2):
  /// entity kod-çakışmasında platformlar-arası sızıntıyı önlemek için okuma
  /// filtresi. Kayıtlı değilse null → filtre uygulanmaz (tenant-scoped RLS korur).
  String? get _activePlatformId => sl.isRegistered<PlatformContext>()
      ? sl<PlatformContext>().activePlatformId
      : null;

  // ============================================
  // LIST
  // ============================================

  /// Bir entity tipine ait kayıtları listele.
  ///
  /// [config.isStandalone] true ise `form_submissions` sorgulanır; aksi halde
  /// [config.linkedTable] (varsa) best-effort generic olarak sorgulanır.
  Future<List<GenericEntity>> listEntities(
    EntityTypeConfig config, {
    int limit = 50,
    int offset = 0,
    String? search,
    String? ancestorId,
  }) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    if (!config.isStandalone && config.linkedTable != null) {
      return _listLinked(config, limit: limit, offset: offset);
    }

    try {
      var query = _supabase
          .from('form_submissions')
          .select('*, form_templates(name, code)')
          .eq('tenant_id', _currentTenantId!)
          .eq('entity_type', config.code)
          .eq('is_standalone', true)
          .eq('active', true);

      // Platform izolasyonu: bu platform + paylaşılan (NULL) kayıtlar.
      final pid = _activePlatformId;
      if (pid != null) {
        query = query.or('platform_id.is.null,platform_id.eq.$pid');
      }

      // Proje/üst-öğe kapsamı: hierarchy_path nokta-ayrık materialized-path
      // (ör. 'projectId.epicId.storyId') → altında olan kayıtları filtreler.
      if (ancestorId != null && ancestorId.isNotEmpty) {
        query = query.ilike('hierarchy_path', '%$ancestorId%');
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim();
        query = query.or('subject.ilike.%$term%,code.ilike.%$term%');
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final rows = (response as List).cast<Map<String, dynamic>>();

      Logger.debug('listEntities(${config.code}) returned ${rows.length} rows');

      // Atanan id: base assigned_to → yoksa metadata.owner lookup (CRM'de atanan
      // base kolonda değil). Tek toplu sorguyla ad + avatar çöz (liste rozetleri).
      final ids = rows
          .map(_assigneeIdOfRow)
          .whereType<String>()
          .toSet()
          .toList();
      final profiles = await _resolveAssigneeProfiles(ids);

      return rows.map((row) {
        final aid = _assigneeIdOfRow(row);
        final p = aid != null ? profiles[aid] : null;
        final meta = row['metadata'];
        final name = p?.name ??
            (meta is Map ? _ownerNameFrom(meta['owner']) : null);
        return GenericEntity.fromSubmission(
          row,
          assignedToName: name,
          assignedToAvatar: p?.avatar,
        );
      }).toList();
    } catch (e) {
      Logger.error('Error listing entities (${config.code}): $e');
      rethrow;
    }
  }

  /// Bağlı tablo (linked_table) için basit generic listeleme.
  Future<List<GenericEntity>> _listLinked(
    EntityTypeConfig config, {
    int limit = 50,
    int offset = 0,
  }) async {
    final table = config.linkedTable!;
    try {
      final response = await _supabase
          .from(table)
          .select('*')
          .eq('tenant_id', _currentTenantId!)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      final rows = (response as List).cast<Map<String, dynamic>>();

      Logger.debug('listEntities linked $table returned ${rows.length} rows');

      return rows
          .map((row) => GenericEntity.fromLinkedRow(row, config.code))
          .toList();
    } catch (e) {
      Logger.error('Error listing linked entities ($table): $e');
      rethrow;
    }
  }

  // ============================================
  // GET SINGLE
  // ============================================

  /// Tek bir entity kaydını (bağımsız) alan değerleriyle birlikte getir.
  Future<GenericEntity?> getEntity(EntityTypeConfig config, String id) async {
    try {
      if (!config.isStandalone && config.linkedTable != null) {
        final row = await _supabase
            .from(config.linkedTable!)
            .select('*')
            .eq('id', id)
            .maybeSingle();
        if (row == null) return null;
        return GenericEntity.fromLinkedRow(row, config.code);
      }

      final row = await _supabase
          .from('form_submissions')
          .select('*, form_templates(name, code)')
          .eq('id', id)
          .maybeSingle();

      if (row == null) return null;

      // Alan değerleri İKİ kaynakta olabilir: (a) form_submissions.metadata
      // (jsonb, field-code anahtarlı — CRM lead/deal buraya yazar; binlerce
      // kayıt) ve (b) tipli form_field_values tablosu. Taban=metadata, üstüne
      // tipli değerler (varsa) bindirilir. Tek-kaynak okumak detayı boş
      // gösteriyordu ("bilgiler yansımıyor").
      final meta = row['metadata'] is Map
          ? Map<String, dynamic>.from(row['metadata'] as Map)
          : <String, dynamic>{};
      final typed = await _loadFieldValues(id);
      final fieldValues = <String, dynamic>{...meta};
      typed.forEach((k, v) {
        if (v != null) fieldValues[k] = v;
      });
      fieldValues.removeWhere((k, v) => v == null);

      // Atanan: base assigned_to kolonu → yoksa metadata owner/assignee lookup
      // (CRM'de atanan base kolonda DEĞİL, metadata'daki 'owner' lookup'ında).
      String? assignee = (row['assigned_to'] as String?);
      if (assignee == null || assignee.isEmpty) {
        assignee = _ownerIdFrom(meta['owner']) ?? _ownerIdFrom(meta['assignee']);
      }
      String? assigneeName;
      String? assigneeAvatar;
      if (assignee != null && assignee.isNotEmpty) {
        final profiles = await _resolveAssigneeProfiles([assignee]);
        final p = profiles[assignee];
        assigneeName = p?.name;
        assigneeAvatar = p?.avatar;
      }
      // Lookup objesi displayValue taşıyorsa ve profil çözülemediyse ona düş.
      assigneeName ??= _ownerNameFrom(meta['owner']);

      // PPM native ilişkileri: sprint + üst-epik adları (id → ad, hafif sorgu;
      // yalnız doluysa). PPM gerçek alanları metadata'da değil native
      // kolonlarda olduğundan detay bunlar olmadan boş görünüyordu.
      final sprintId = row['sprint_id'] as String?;
      final sprintName = (sprintId != null && sprintId.isNotEmpty)
          ? await _lookupName('sprints', sprintId, 'name')
          : null;
      final parentId = row['parent_entity_id'] as String?;
      final parentSubject = (parentId != null && parentId.isNotEmpty)
          ? await _lookupName('form_submissions', parentId, 'subject')
          : null;

      return GenericEntity.fromSubmission(
        row,
        fieldValues: fieldValues,
        assignedToName: assigneeName,
        assignedToAvatar: assigneeAvatar,
        sprintName: sprintName,
        parentSubject: parentSubject,
      );
    } catch (e) {
      Logger.error('Error fetching entity (${config.code}/$id): $e');
      rethrow;
    }
  }

  /// Bir submission'ın alan değerlerini kod → değer olarak düzleştir.
  Future<Map<String, dynamic>> _loadFieldValues(String submissionId) async {
    final response = await _supabase
        .from('form_field_values')
        .select('*, form_field:form_fields(code, field_type)')
        .eq('form_submission_id', submissionId)
        .eq('active', true);

    final rows = (response as List).cast<Map<String, dynamic>>();
    final result = <String, dynamic>{};

    for (final row in rows) {
      final field = row['form_field'];
      if (field is! Map) continue;
      final code = field['code'] as String?;
      if (code == null) continue;
      final fieldType = field['field_type'] as String? ?? 'text';
      result[code] = _extractValue(row, fieldType);
    }

    return result;
  }

  /// Alan tipine göre doğru `value_*` kolonunu seç (gerekirse fallback).
  dynamic _extractValue(Map<String, dynamic> row, String fieldType) {
    dynamic byType;
    switch (fieldType) {
      case 'number':
      case 'currency':
      case 'percentage':
      case 'rating':
        byType = row['value_number'];
        break;
      case 'date':
      case 'datetime':
        byType = row['value_date'];
        break;
      case 'checkbox':
        byType = row['value_boolean'];
        break;
      case 'multiselect':
      case 'file':
      case 'image':
      case 'location':
      case 'signature':
      case 'daterange':
      case 'lookup':
        byType = row['value_json'];
        break;
      default:
        // text, textarea, email, phone, select, radio, barcode, rich_text, ...
        byType = row['value_text'];
    }

    if (byType != null) return byType;

    // Fallback: alan tipi ile eşleşen kolon boşsa ilk dolu kolonu döndür.
    return row['value_text'] ??
        row['value_number'] ??
        row['value_boolean'] ??
        row['value_date'] ??
        row['value_json'];
  }

  // ============================================
  // SUBMIT (via Edge Function)
  // ============================================

  /// Bir entity kaydını `form-submit` Edge Function üzerinden gönder/kaydet.
  ///
  /// [asDraft] true ise action 'save', aksi halde 'submit' olur. EF zarfı
  /// `{success, data|error}` biçiminde çözülür; `success == false` ise hata
  /// fırlatılır.
  Future<Map<String, dynamic>> submitEntity({
    required String templateId,
    required Map<String, dynamic> values,
    required String entityType,
    String? entityId,
    String? submissionId,
    bool asDraft = false,
  }) async {
    // OFFLINE fallback: bağlantı yoksa işlemi kuyruğa al ve iyimser (optimistic)
    // dön. Online olunca OfflineSyncService kuyruğu boşaltıp bu işlemi
    // [replaySubmit] üzerinden yeniden oynatır. Online path DEĞİŞMEDİ.
    final sync = _offlineSyncOrNull;
    if (sync != null && (_connectivityOrNull?.isOffline ?? false)) {
      final op = await sync.addOperation(
        type: PendingOperationType.create,
        entityType: kEntitySubmitOpType,
        entityId: entityId ?? submissionId,
        data: {
          'templateId': templateId,
          'values': values,
          'entityType': entityType,
          'entityId': entityId,
          'submissionId': submissionId,
          'asDraft': asDraft,
        },
      );
      Logger.info(
          'Offline: entity submit queued (${op.id}, type=$entityType)');
      return {
        'queued': true,
        'offline': true,
        'opId': op.id,
        'submissionId': submissionId,
        'entityId': entityId,
      };
    }

    return _submitEntityToNetwork(
      templateId: templateId,
      values: values,
      entityType: entityType,
      entityId: entityId,
      submissionId: submissionId,
      asDraft: asDraft,
    );
  }

  /// Gerçek ağ yazımı (`form-submit` EF). Online path burada; offline kuyruk
  /// replay'i de doğrudan bunu çağırır.
  Future<Map<String, dynamic>> _submitEntityToNetwork({
    required String templateId,
    required Map<String, dynamic> values,
    required String entityType,
    String? entityId,
    String? submissionId,
    bool asDraft = false,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'form-submit',
        body: {
          'templateId': templateId,
          'values': values,
          'entityType': entityType,
          'entityId': entityId,
          'submissionId': submissionId,
          'action': asDraft ? 'save' : 'submit',
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        if (data['success'] == false) {
          final error = data['error'];
          throw Exception('form-submit failed: ${error ?? 'unknown error'}');
        }
        final inner = data['data'];
        if (inner is Map<String, dynamic>) return inner;
        return data;
      }

      throw Exception('form-submit returned unexpected payload: $data');
    } catch (e) {
      Logger.error('Error submitting entity ($entityType): $e');
      rethrow;
    }
  }

  /// Offline kuyruk replay handler'ı: kaydedilmiş payload ile form-submit'i
  /// yeniden oynatır. Başarıda `true` döner (OfflineSyncService kaydı siler);
  /// hata fırlatırsa retry/dead-letter mantığı devreye girer.
  ///
  /// Idempotency notu: `form-submit` EF NEW gönderimlerde yalnızca son 10 sn
  /// içindeki birebir kopyayı ayıklar (kalıcı bir idempotency anahtarı yok) ve
  /// uydurma bir `submissionId` UPDATE→404 verir; bu yüzden ağ yazımı başarılı
  /// olup yanıt kaybolursa (kuyruktan silinmeden önce) gecikmiş bir replay
  /// KOPYA yaratabilir. Birincil koruma kuyruğun başarı→sil davranışıdır.
  Future<bool> replaySubmit(PendingOperation op) async {
    final d = op.data;
    await _submitEntityToNetwork(
      templateId: d['templateId'] as String,
      values: (d['values'] as Map).cast<String, dynamic>(),
      entityType: d['entityType'] as String,
      entityId: d['entityId'] as String?,
      submissionId: d['submissionId'] as String?,
      asDraft: d['asDraft'] as bool? ?? false,
    );
    return true;
  }

  // Offline-queue erişimi (kayıtlı değilse — ör. testte — null döner; bu
  // durumda submitEntity doğrudan ağ path'ine düşer, davranış değişmez).
  ConnectivityService? get _connectivityOrNull =>
      sl.isRegistered<ConnectivityService>()
          ? sl<ConnectivityService>()
          : null;

  OfflineSyncService? get _offlineSyncOrNull {
    if (!sl.isRegistered<OfflineSyncService>()) return null;
    final s = sl<OfflineSyncService>();
    return s.isInitialized ? s : null;
  }

  // ============================================
  // STATUS (Kanban)
  // ============================================

  /// Bir entity tipi için aktif durum tanımlarını (`status_definitions`)
  /// getir. Web `PtbStatusService.fetchDefinitions` ile aynı sözleşme:
  /// `sort_order`'a göre sıralı; aynı `code` için tenant satırı
  /// (`is_system=false`) sistem satırını override eder.
  ///
  /// Hata durumunda boş liste döner (kanban distinct-status fallback'ine
  /// düşebilsin diye ASLA fırlatmaz).
  Future<List<Map<String, dynamic>>> loadStatusDefinitions(
    String entityType,
  ) async {
    try {
      final response = await _supabase
          .from('status_definitions')
          .select(
            'id, code, name, color, icon, is_initial, is_final, sort_order, is_system',
          )
          .eq('entity_type', entityType)
          .eq('active', true)
          .order('sort_order', ascending: true);

      final rows = (response as List).cast<Map<String, dynamic>>();

      // Dedup: tenant override (is_system=false) aynı code'da sistemi yener.
      final byCode = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final code = row['code'] as String?;
        if (code == null) continue;
        final existing = byCode[code];
        if (existing == null || row['is_system'] != true) {
          byCode[code] = row;
        }
      }

      final result = byCode.values.toList()
        ..sort((a, b) => ((a['sort_order'] as num?) ?? 0)
            .compareTo((b['sort_order'] as num?) ?? 0));

      Logger.debug(
        'loadStatusDefinitions($entityType) returned ${result.length} columns',
      );
      return result;
    } catch (e) {
      Logger.error('Error loading status definitions ($entityType): $e');
      return [];
    }
  }

  /// Bir entity kaydının durumunu `status-transition` Edge Function üzerinden
  /// güncelle (Kanban sürükle-bırak). Web `PtbStatusService.executeTransition`
  /// ile aynı sözleşme: EF geçişi `status_transitions`'a göre doğrular,
  /// rol/yorum/form kontrollerini yapar ve durumu service-role ile yazar.
  ///
  /// Doğrudan client `UPDATE form_submissions SET status` KULLANILMAZ: hem
  /// `tenant_isolation_form_submissions` RLS'i hem de `BEFORE UPDATE`
  /// `check_submission_status_transition()` trigger'ı (geçersiz geçişte
  /// `check_violation` / 23514) bunu reddeder — bu yüzden yazım EF'e yönlenir.
  ///
  /// [entityType] `entity_type_configs.code`'dur; bağımsız (standalone)
  /// entity'ler için [entityId] doğrudan `form_submissions.id`'dir. EF zarfı
  /// `{success, data|error}`; başarısızlıkta (2xx-dışı yanıt ya da
  /// `success == false`) hata fırlatılır ve ekran optimistic taşımayı geri alır.
  Future<void> updateStatus({
    required String entityType,
    required String entityId,
    required String toStatus,
    String? comment,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'status-transition',
        body: {
          'entityType': entityType,
          'entityId': entityId,
          'toStatus': toStatus,
          if (comment != null && comment.trim().isNotEmpty)
            'comment': comment.trim(),
        },
      );

      final data = response.data;
      if (data is Map<String, dynamic> && data['success'] == false) {
        final error = data['error'];
        throw Exception('status-transition failed: ${error ?? 'unknown error'}');
      }

      Logger.debug('updateStatus($entityType/$entityId -> $toStatus) ok');
    } catch (e) {
      Logger.error('Error updating status ($entityId -> $toStatus): $e');
      rethrow;
    }
  }

  // ============================================
  // BACKLOG (reorder / rank)
  // ============================================

  /// Backlog sırasında iki komşu kayıt arasına yeni bir kayıt eklerken
  /// kullanılan boşluk; web `ptb-backlog` RANK_STEP ile aynı.
  static const int _backlogRankStep = 1000;

  /// Backlog ekranı için kayıtları `backlog_rank`'e göre (NULL'lar sona,
  /// eşitlikte `created_at` artan) getirir — web `ptb-backlog`'un `sortByRank`
  /// sırasını yansıtır. Yalnız bağımsız (standalone) entity'ler.
  Future<List<GenericEntity>> loadBacklog(
    EntityTypeConfig config, {
    int limit = 200,
    String? ancestorId,
  }) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    try {
      var q = _supabase
          .from('form_submissions')
          .select('*, form_templates(name, code)')
          .eq('tenant_id', _currentTenantId!)
          .eq('entity_type', config.code)
          .eq('is_standalone', true)
          .eq('active', true);
      // Platform izolasyonu: bu platform + paylaşılan (NULL) kayıtlar.
      final pid = _activePlatformId;
      if (pid != null) {
        q = q.or('platform_id.is.null,platform_id.eq.$pid');
      }
      // Proje/üst-öğe kapsamı (hierarchy_path subtree) — board ile aynı.
      if (ancestorId != null && ancestorId.isNotEmpty) {
        q = q.ilike('hierarchy_path', '%$ancestorId%');
      }
      final response = await q
          .order('backlog_rank', ascending: true, nullsFirst: false)
          .order('created_at', ascending: true)
          .limit(limit);
      final rows = (response as List).cast<Map<String, dynamic>>();

      Logger.debug('loadBacklog(${config.code}) returned ${rows.length} rows');

      final names = await _resolveAssigneeNames(rows);

      return rows.map((row) {
        final assignee = row['assigned_to'] as String?;
        return GenericEntity.fromSubmission(
          row,
          assignedToName: assignee != null ? names[assignee] : null,
        );
      }).toList();
    } catch (e) {
      Logger.error('Error loading backlog (${config.code}): $e');
      rethrow;
    }
  }

  /// Backlog sırasını KALICI yazar: verilen id sırasına göre her kayda eşit
  /// aralıklı yeni bir `backlog_rank` `((index + 1) * 1000)` atar. Web
  /// `PtbSprintService.rerankBatch` ile AYNI yol: doğrudan `form_submissions`
  /// UPDATE (`id` + `tenant_id` scope'lu, `updated_by` yazılır).
  ///
  /// Bu, Kanban `status` yazımından FARKLIDIR ve doğrudan tablo UPDATE'i güvenle
  /// kullanır: `check_submission_status_transition()` trigger'ı yalnız `status`
  /// değişince tetiklenir; yalnız `backlog_rank` güncellemesi
  /// `tenant_isolation_form_submissions` RLS'i ve entity `update` izni altında
  /// geçer (web bu yolu prod'da kullanır). Herhangi bir satır başarısız olursa
  /// hata fırlatır — çağıran optimistic sırayı geri alır.
  Future<void> reorderBacklog(List<String> orderedIds) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }
    if (orderedIds.isEmpty) return;

    try {
      // ATOMİK: tek RPC (fn_reorder_backlog) → tek transaction'da unnest UPDATE.
      // Eski N-ayrı-UPDATE kısmi-fail'de DB/UI drift bırakıyordu.
      final ranks = List<int>.generate(
          orderedIds.length, (i) => (i + 1) * _backlogRankStep);
      await _supabase.rpc('fn_reorder_backlog', params: {
        'p_ids': orderedIds,
        'p_ranks': ranks,
      });
      Logger.debug(
          'reorderBacklog persisted ${orderedIds.length} ranks (atomic)');
    } catch (e) {
      Logger.error('Error reordering backlog: $e');
      rethrow;
    }
  }

  // ============================================
  // HELPERS
  // ============================================

  /// Verilen satırlardaki `assigned_to` id'leri için görünen adları çöz.
  Future<Map<String, String>> _resolveAssigneeNames(
    List<Map<String, dynamic>> rows,
  ) async {
    final ids = rows
        .map((r) => r['assigned_to'] as String?)
        .where((id) => id != null)
        .cast<String>()
        .toSet()
        .toList();

    if (ids.isEmpty) return {};

    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, first_name, last_name, email')
          .inFilter('id', ids);
      final rows = (response as List).cast<Map<String, dynamic>>();

      final result = <String, String>{};
      for (final row in rows) {
        final id = row['id'] as String?;
        if (id == null) continue;
        result[id] = _displayName(row);
      }
      return result;
    } catch (e) {
      Logger.warning('Failed to resolve assignee names: $e');
      return {};
    }
  }

  String _displayName(Map<String, dynamic> profile) {
    final fullName = (profile['full_name'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;

    final first = (profile['first_name'] as String?)?.trim() ?? '';
    final last = (profile['last_name'] as String?)?.trim() ?? '';
    final combined = '$first $last'.trim();
    if (combined.isNotEmpty) return combined;

    final email = profile['email'] as String?;
    if (email != null && email.isNotEmpty) return email.split('@').first;

    return '';
  }

  /// Verilen profil id'leri için görünen ad + HAM avatar yolunu çöz.
  /// (Avatar imzalanmamış döner; gösterirken FileStorageService.getAvatarUrl.)
  Future<Map<String, ({String name, String? avatar})>> _resolveAssigneeProfiles(
    List<String> ids,
  ) async {
    final unique = ids.where((s) => s.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return {};
    try {
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, first_name, last_name, email, avatar_url')
          .inFilter('id', unique);
      final rows = (response as List).cast<Map<String, dynamic>>();
      final result = <String, ({String name, String? avatar})>{};
      for (final row in rows) {
        final id = row['id'] as String?;
        if (id == null) continue;
        final avatar = (row['avatar_url'] as String?)?.trim();
        result[id] = (
          name: _displayName(row),
          avatar: (avatar != null && avatar.isNotEmpty) ? avatar : null,
        );
      }
      return result;
    } catch (e) {
      Logger.warning('Failed to resolve assignee profiles: $e');
      return {};
    }
  }

  /// Bir form_submissions satırının atanan profil id'si: base `assigned_to` →
  /// yoksa `metadata.owner`/`metadata.assignee` lookup (CRM).
  String? _assigneeIdOfRow(Map<String, dynamic> row) {
    final base = row['assigned_to'] as String?;
    if (base != null && base.isNotEmpty) return base;
    final meta = row['metadata'];
    if (meta is Map) {
      return _ownerIdFrom(meta['owner']) ?? _ownerIdFrom(meta['assignee']);
    }
    return null;
  }

  /// Bir lookup/owner değerinden profil id'sini çıkar.
  /// Şekiller: düz uuid String, ya da `{entityId|value|id, displayValue}` objesi.
  String? _ownerIdFrom(dynamic v) {
    if (v == null) return null;
    if (v is String) {
      final s = v.trim();
      return s.isEmpty ? null : s;
    }
    if (v is Map) {
      final e = v['entityId'] ?? v['value'] ?? v['id'];
      if (e is String && e.trim().isNotEmpty) return e.trim();
    }
    return null;
  }

  /// Bir tablodaki tek satırın adını (verilen kolon) id ile çöz — best-effort.
  Future<String?> _lookupName(String table, String id, String column) async {
    try {
      final res = await _supabase
          .from(table)
          .select(column)
          .eq('id', id)
          .maybeSingle();
      if (res == null) return null;
      final v = res[column];
      return (v is String && v.trim().isNotEmpty) ? v.trim() : null;
    } catch (e) {
      Logger.warning('Failed to lookup $table.$column ($id): $e');
      return null;
    }
  }

  /// Lookup objesindeki hazır görünen-ad (displayValue) — profil çözülemezse.
  String? _ownerNameFrom(dynamic v) {
    if (v is Map) {
      final d = v['displayValue'];
      if (d is String && d.trim().isNotEmpty) return d.trim();
    }
    return null;
  }

  /// Cache'i temizle.
  Future<void> invalidateCache() async {
    if (_currentTenantId != null) {
      await _cacheManager
          .deleteWhere((key) => key.startsWith('entity_data_$_currentTenantId'));
    }
  }
}
