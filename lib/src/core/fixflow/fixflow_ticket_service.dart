import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../di/service_locator.dart';
import '../storage/file_storage_service.dart';
import '../utils/logger.dart';
import 'fixflow_models.dart';
import 'fixflow_session.dart';

/// FixFlow bilet (iş emri) servisi — teknisyen odaklı. Web
/// `fixflow-core/ticket.service.ts` + `@ptb/core` worklog/attachment
/// servisleri ile aynı tablolar/kolonlar:
///
/// - Liste/detay: `tickets` (+ `priorities!priority_id`, `categories`,
///   `locations`, `assignedTo:profiles!assigned_to`), `active = true`.
///   Tenant izolasyonu RLS (`tenant_isolation_tickets` + `orgiso_tickets_sel`)
///   ve ek `tenant_id` filtresi.
/// - Efor: `worklogs` (entity_type='ticket', `time_spent` DAKİKA).
/// - Ek: dosya `platform-private`'a [FileStorageService.uploadBytes]
///   (`{PLATFORM}/{tenant}/{org}/document/{uuid}-{ad}` — web `uploadPrivate`
///   ile aynı yol + `storage_objects` kaydı), ardından `attachments` satırı.
/// - Durum değişikliği BURADA YOK → [FixflowStatusService.executeTransition].
class FixflowTicketService {
  final SupabaseClient _supabase;
  final FixflowSession _session;
  final FileStorageService? _storage;

  FixflowTicketService({
    required SupabaseClient supabase,
    FixflowSession? session,
    FileStorageService? storage,
  })  : _supabase = supabase,
        _session = session ?? AppFixflowSession(supabase),
        _storage = storage;

  static const String _listSelect =
      '*, priorities!priority_id(code, name, color), '
      'locations!location_id(name), categories!category_id(name)';

  static const String _detailSelect =
      '*, priorities!priority_id(code, name, color), '
      'categories!category_id(id, name), locations!location_id(id, name), '
      'assignedTo:profiles!assigned_to(id, full_name, username)';

  FileStorageService get _files =>
      _storage ?? sl<FileStorageService>();

  /// Kullanıcının üyesi olduğu ekipler (`team_staffs` ⋈ kendi `staffs`
  /// satırları). Hata/boş → [].
  Future<List<String>> myTeamIds() async {
    final uid = _session.userId;
    if (uid == null) return const [];
    try {
      final staffRes = await _supabase
          .from('staffs')
          .select('id')
          .eq('profile_id', uid)
          .eq('active', true);
      final staffIds = (staffRes as List)
          .map((r) => (r as Map)['id']?.toString())
          .whereType<String>()
          .toList();
      if (staffIds.isEmpty) return const [];
      final teamRes = await _supabase
          .from('team_staffs')
          .select('team_id')
          .inFilter('staff_id', staffIds)
          .or('active.is.null,active.eq.true');
      return (teamRes as List)
          .map((r) => (r as Map)['team_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
    } catch (e) {
      Logger.error('FixFlow myTeamIds failed', e);
      return const [];
    }
  }

  /// Bilet listesi. [statuses] boş/null → tüm durumlar. [scope]=team ve
  /// kullanıcının ekibi yoksa boş döner (ağ çağrısı yapılmaz).
  ///
  /// [orderByDue] true → `due_date` artan (SLA görünümü), aksi → en yeni.
  /// Hata fırlatır (ekran hata durumunu gösterir).
  Future<List<FixflowTicket>> listTickets({
    FixflowTicketScope scope = FixflowTicketScope.mine,
    List<String>? statuses,
    String? search,
    bool orderByDue = false,
    int limit = 100,
  }) async {
    // Kapsam önce çözülür: ekip/oturum yoksa bilet sorgusu hiç kurulmaz.
    final uid = _session.userId;
    List<String> teams = const [];
    if (scope == FixflowTicketScope.mine && uid == null) return const [];
    if (scope == FixflowTicketScope.team) {
      teams = await myTeamIds();
      if (teams.isEmpty) return const [];
    }

    var query = _supabase.from('tickets').select(_listSelect).eq('active', true);
    final tenantId = _session.tenantId;
    if (tenantId != null) query = query.eq('tenant_id', tenantId);
    switch (scope) {
      case FixflowTicketScope.mine:
        query = query.eq('assigned_to', uid!);
        break;
      case FixflowTicketScope.team:
        query = query.inFilter('assigned_team_id', teams);
        break;
      case FixflowTicketScope.all:
        break;
    }

    if (statuses != null && statuses.isNotEmpty) {
      query = statuses.length == 1
          ? query.eq('status', statuses.first)
          : query.inFilter('status', statuses);
    }
    final term = search?.replaceAll(RegExp(r'[%,()"\\]'), ' ').trim();
    if (term != null && term.isNotEmpty) {
      query = query.or('subject.ilike.%$term%,description.ilike.%$term%');
    }

    final res = orderByDue
        ? await query
            .order('due_date', ascending: true, nullsFirst: false)
            .limit(limit)
        : await query.order('created_at', ascending: false).limit(limit);
    return (res as List)
        .map((r) => FixflowTicket.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Tek bilet (id ya da `TKT-0001` kodu). Görünmüyor/yok → null.
  Future<FixflowTicket?> getTicket(String idOrCode) async {
    final isUuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(idOrCode);
    final base =
        _supabase.from('tickets').select(_detailSelect).eq('active', true);
    final row = await (isUuid ? base.eq('id', idOrCode) : base.eq('code', idOrCode))
        .maybeSingle();
    if (row == null) return null;
    return FixflowTicket.fromJson(Map<String, dynamic>.from(row));
  }

  /// Açık bilet sayısı (head count). Hata → 0.
  Future<int> countTickets({
    required FixflowTicketScope scope,
    required List<String> statuses,
    DateTime? dueBefore,
  }) async {
    try {
      final uid = _session.userId;
      List<String> teams = const [];
      if (scope == FixflowTicketScope.mine && uid == null) return 0;
      if (scope == FixflowTicketScope.team) {
        teams = await myTeamIds();
        if (teams.isEmpty) return 0;
      }
      var query = _supabase.from('tickets').select('id').eq('active', true);
      final tenantId = _session.tenantId;
      if (tenantId != null) query = query.eq('tenant_id', tenantId);
      if (scope == FixflowTicketScope.mine) {
        query = query.eq('assigned_to', uid!);
      } else if (scope == FixflowTicketScope.team) {
        query = query.inFilter('assigned_team_id', teams);
      }
      if (statuses.isNotEmpty) query = query.inFilter('status', statuses);
      if (dueBefore != null) {
        query = query.lt('due_date', dueBefore.toUtc().toIso8601String());
      }
      final res = await query.count(CountOption.exact);
      return res.count;
    } catch (e) {
      Logger.error('FixFlow countTickets failed', e);
      return 0;
    }
  }

  // ─── Worklogs ──────────────────────────────────────────────────────────

  /// Biletin efor kayıtları (yeni → eski). Hata → [].
  Future<List<FixflowWorklog>> listWorklogs(
    String entityId, {
    String entityType = FixflowConstants.ticketEntity,
  }) async {
    try {
      final res = await _supabase
          .from('worklogs')
          .select('id, description, time_spent, work_date, created_by, created_at')
          .eq('entity_type', entityType)
          .eq('entity_id', entityId)
          .order('work_date', ascending: false);
      return (res as List)
          .map((r) =>
              FixflowWorklog.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      Logger.error('FixFlow worklogs ($entityId) failed', e);
      return const [];
    }
  }

  /// Efor ekle (web `WorklogService.insertWorklog` ile aynı kolonlar).
  /// [minutes] > 0 olmalı. Hata fırlatır.
  Future<FixflowWorklog> addWorklog({
    required String entityId,
    required int minutes,
    String? description,
    DateTime? workDate,
    String entityType = FixflowConstants.ticketEntity,
  }) async {
    if (minutes <= 0) throw ArgumentError.value(minutes, 'minutes');
    final d = (workDate ?? DateTime.now());
    final dateStr =
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final row = await _supabase
        .from('worklogs')
        .insert({
          'id': const Uuid().v4(),
          'description': (description ?? '').trim(),
          'time_spent': minutes,
          'work_date': dateStr,
          'entity_type': entityType,
          'entity_id': entityId,
          'created_by': _session.userId,
          'tenant_id': _session.tenantId,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id, description, time_spent, work_date, created_by, created_at')
        .single();
    return FixflowWorklog.fromJson(Map<String, dynamic>.from(row));
  }

  // ─── Attachments ───────────────────────────────────────────────────────

  /// Biletin ekleri (yeni → eski). Hata → [].
  Future<List<FixflowAttachment>> listAttachments(
    String entityId, {
    String entityType = FixflowConstants.ticketEntity,
  }) async {
    try {
      final res = await _supabase
          .from('attachments')
          .select('id, filename, original_filename, file_size, mime_type, file_path, created_by, created_at')
          .eq('entity_type', entityType)
          .eq('entity_id', entityId)
          .eq('active', true)
          .order('created_at', ascending: false);
      return (res as List)
          .map((r) =>
              FixflowAttachment.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      Logger.error('FixFlow attachments ($entityId) failed', e);
      return const [];
    }
  }

  /// Fotoğraf/dosya ekle: önce `platform-private`'a yükle (+ registry), sonra
  /// `attachments` satırı. Web `AttachmentService.doUpload` ile aynı satır
  /// (web `work_request_id`'yi de entity id ile doldurur — birebir korunur).
  /// Hata fırlatır; satır yazılamazsa yüklenen nesne temizlenmez (web ile
  /// aynı davranış — `storage_objects` kaydı kota hesabında kalır).
  Future<FixflowAttachment> uploadAttachment({
    required String entityId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
    String entityType = FixflowConstants.ticketEntity,
  }) async {
    final up = await _files.uploadBytes(
      bytes: bytes,
      fileName: fileName,
      category: StorageCategory.document,
      access: StorageAccessLevel.private,
      contentType: mimeType,
      tenantId: _session.tenantId,
      organizationId: await _session.organizationId(),
      entityType: entityType,
      entityId: entityId,
    );
    if (!up.success || up.path == null) {
      throw StateError(up.error ?? 'upload failed');
    }
    final path = up.path!;
    final row = await _supabase
        .from('attachments')
        .insert({
          'id': const Uuid().v4(),
          'filename': path.split('/').last,
          'original_filename': fileName,
          'file_size': bytes.length,
          'mime_type': mimeType ?? 'application/octet-stream',
          'file_path': path,
          'work_request_id': entityId,
          'entity_type': entityType,
          'entity_id': entityId,
          'created_by': _session.userId,
          'tenant_id': _session.tenantId,
          'active': true,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id, filename, original_filename, file_size, mime_type, file_path, created_by, created_at')
        .single();
    return FixflowAttachment.fromJson(Map<String, dynamic>.from(row));
  }

  /// Ekin imzalı URL'i (private bucket; registry + tenant-path RLS).
  Future<String?> attachmentUrl(FixflowAttachment a) => _files.getSignedUrl(
        bucket: StorageBuckets.platformPrivate,
        path: a.filePath,
      );
}
