import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/cache_manager.dart';
import '../utils/logger.dart';
import 'calendar_event_model.dart';

/// Calendar Service
///
/// Takvim etkinliklerini yönetir. CRUD operasyonları,
/// tekrarlayan etkinlikler, hatırlatıcılar ve katılımcı yönetimi sağlar.
class CalendarService {
  final SupabaseClient _supabase;
  final CacheManager _cacheManager;

  /// Etkinlik listesi stream
  final _eventsController = StreamController<List<CalendarEvent>>.broadcast();

  /// Seçili etkinlik stream
  final _selectedController = StreamController<CalendarEvent?>.broadcast();

  /// Mevcut tenant ID
  String? _currentTenantId;

  /// Mevcut kullanıcı ID
  String? _currentUserId;

  /// Mevcut etkinlik listesi
  List<CalendarEvent> _events = [];

  /// Seçili etkinlik
  CalendarEvent? _selected;

  CalendarService({
    required SupabaseClient supabase,
    required CacheManager cacheManager,
  })  : _supabase = supabase,
        _cacheManager = cacheManager;

  // ============================================
  // GETTERS
  // ============================================

  /// Etkinlik listesi stream
  Stream<List<CalendarEvent>> get eventsStream => _eventsController.stream;

  /// Seçili etkinlik stream
  Stream<CalendarEvent?> get selectedStream => _selectedController.stream;

  /// Mevcut etkinlik listesi
  List<CalendarEvent> get events => List.unmodifiable(_events);

  /// Seçili etkinlik
  CalendarEvent? get selected => _selected;

  /// Bugünün etkinlikleri
  List<CalendarEvent> get todayEvents =>
      _events.where((e) => e.isToday && e.isActive).toList();

  /// Gelecek etkinlikler
  List<CalendarEvent> get upcomingEvents =>
      _events.where((e) => e.isFuture && e.isActive).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

  /// Bakım etkinlikleri
  List<CalendarEvent> get maintenanceEvents =>
      _events.where((e) => e.type == CalendarEventType.maintenance).toList();

  /// Toplantılar
  List<CalendarEvent> get meetingEvents =>
      _events.where((e) => e.type == CalendarEventType.meeting).toList();

  // ============================================
  // CONTEXT
  // ============================================

  /// Tenant context'ini ayarla
  void setTenant(String tenantId) {
    if (_currentTenantId != tenantId) {
      _currentTenantId = tenantId;
      _events = [];
      _selected = null;
      _eventsController.add(_events);
      _selectedController.add(_selected);
    }
  }

  /// Kullanıcı context'ini ayarla
  void setUser(String userId) {
    _currentUserId = userId;
  }

  /// Context'i temizle
  void clearContext() {
    _currentTenantId = null;
    _currentUserId = null;
    _events = [];
    _selected = null;
    _eventsController.add(_events);
    _selectedController.add(_selected);
  }

  // ============================================
  // CRUD OPERATIONS
  // ============================================

  /// Tarih aralığındaki etkinlikleri getir
  Future<List<CalendarEvent>> getEvents({
    required DateTime startDate,
    required DateTime endDate,
    String? siteId,
    CalendarEventType? type,
    CalendarEventStatus? status,
    bool forceRefresh = false,
  }) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    final cacheKey = 'calendar_events_${_currentTenantId}_${startDate.toIso8601String()}_${endDate.toIso8601String()}';

    // Cache kontrolü
    if (!forceRefresh) {
      final cached = await _cacheManager.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        try {
          _events = cached
              .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
              .toList();
          _eventsController.add(_events);
          return _applyFilters(type: type, status: status);
        } catch (cacheError) {
          Logger.warning('Failed to parse calendar events from cache: $cacheError');
          await _cacheManager.delete(cacheKey);
        }
      }
    }

    try {
      var query = _supabase
          .from('calendar_events')
          .select()
          .eq('tenant_id', _currentTenantId!)
          .gte('start_time', startDate.toIso8601String())
          .lte('start_time', endDate.toIso8601String());

      if (siteId != null) {
        query = query.eq('site_id', siteId);
      }

      if (type != null) {
        query = query.eq('type', type.value);
      }

      if (status != null) {
        query = query.eq('status', status.value);
      }

      final response = await query.order('start_time');
      final responseList = response as List;

      Logger.debug('Calendar events query returned ${responseList.length} records');

      _events = responseList
          .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache'e kaydet
      await _cacheManager.set(
        cacheKey,
        responseList,
        ttl: const Duration(minutes: 5),
      );

      _eventsController.add(_events);
      return _events;
    } catch (e) {
      Logger.error('Error fetching calendar events: $e');
      rethrow;
    }
  }

  /// Belirli bir ay için etkinlikleri getir
  Future<List<CalendarEvent>> getEventsForMonth(int year, int month, {String? siteId}) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);
    return getEvents(startDate: startDate, endDate: endDate, siteId: siteId);
  }

  /// Bugünün etkinliklerini getir
  Future<List<CalendarEvent>> getTodayEvents({String? siteId}) async {
    final today = DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day);
    final endDate = DateTime(today.year, today.month, today.day, 23, 59, 59);
    return getEvents(startDate: startDate, endDate: endDate, siteId: siteId);
  }

  /// Gelecek X günün etkinliklerini getir
  Future<List<CalendarEvent>> getUpcomingEvents({
    int days = 7,
    String? siteId,
  }) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: days));
    return getEvents(startDate: now, endDate: endDate, siteId: siteId);
  }

  /// ID ile etkinlik getir
  Future<CalendarEvent?> getById(String id) async {
    try {
      final response = await _supabase
          .from('calendar_events')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      final event = CalendarEvent.fromJson(response);
      _selected = event;
      _selectedController.add(_selected);
      return event;
    } catch (e) {
      Logger.error('Error fetching calendar event by id: $e');
      rethrow;
    }
  }

  /// Yeni etkinlik oluştur
  Future<CalendarEvent> create({
    required String title,
    String? description,
    CalendarEventType type = CalendarEventType.other,
    required DateTime startTime,
    DateTime? endTime,
    bool isAllDay = false,
    String? location,
    String? meetingUrl,
    String? siteId,
    String? unitId,
    String? controllerId,
    RecurrenceFrequency recurrence = RecurrenceFrequency.none,
    int? recurrenceInterval,
    DateTime? recurrenceEndDate,
    List<int>? recurrenceDays,
    List<EventReminder>? reminders,
    List<EventAttendee>? attendees,
    String? color,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    if (_currentUserId == null) {
      throw Exception('User context is not set');
    }

    try {
      final now = DateTime.now();
      final data = {
        'title': title,
        'description': description,
        'type': type.value,
        'status': CalendarEventStatus.scheduled.value,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime?.toIso8601String(),
        'is_all_day': isAllDay,
        'location': location,
        'meeting_url': meetingUrl,
        'tenant_id': _currentTenantId,
        'site_id': siteId,
        'unit_id': unitId,
        'controller_id': controllerId,
        'created_by_id': _currentUserId,
        'recurrence': recurrence.value,
        'recurrence_interval': recurrenceInterval,
        'recurrence_end_date': recurrenceEndDate?.toIso8601String(),
        'recurrence_days': recurrenceDays,
        'reminders': reminders?.map((r) => r.toJson()).toList() ?? [],
        'attendees': attendees?.map((a) => a.toJson()).toList() ?? [],
        'color': color,
        'tags': tags ?? [],
        'metadata': metadata ?? {},
        'created_by': _currentUserId,
        'created_at': now.toIso8601String(),
      };

      final response = await _supabase
          .from('calendar_events')
          .insert(data)
          .select()
          .single();

      final event = CalendarEvent.fromJson(response);

      // Listeye ekle ve stream'i güncelle
      _events.add(event);
      _events.sort((a, b) => a.startTime.compareTo(b.startTime));
      _eventsController.add(_events);

      // Cache'i temizle
      await _invalidateCache();

      Logger.info('Created calendar event: ${event.id}');
      return event;
    } catch (e) {
      Logger.error('Error creating calendar event: $e');
      rethrow;
    }
  }

  /// Etkinlik güncelle
  Future<CalendarEvent> update(
    String id, {
    String? title,
    String? description,
    CalendarEventType? type,
    CalendarEventStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    String? location,
    String? meetingUrl,
    String? siteId,
    String? unitId,
    String? controllerId,
    RecurrenceFrequency? recurrence,
    int? recurrenceInterval,
    DateTime? recurrenceEndDate,
    List<int>? recurrenceDays,
    List<EventReminder>? reminders,
    List<EventAttendee>? attendees,
    String? color,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': _currentUserId,
      };

      if (title != null) data['title'] = title;
      if (description != null) data['description'] = description;
      if (type != null) data['type'] = type.value;
      if (status != null) data['status'] = status.value;
      if (startTime != null) data['start_time'] = startTime.toIso8601String();
      if (endTime != null) data['end_time'] = endTime.toIso8601String();
      if (isAllDay != null) data['is_all_day'] = isAllDay;
      if (location != null) data['location'] = location;
      if (meetingUrl != null) data['meeting_url'] = meetingUrl;
      if (siteId != null) data['site_id'] = siteId;
      if (unitId != null) data['unit_id'] = unitId;
      if (controllerId != null) data['controller_id'] = controllerId;
      if (recurrence != null) data['recurrence'] = recurrence.value;
      if (recurrenceInterval != null) data['recurrence_interval'] = recurrenceInterval;
      if (recurrenceEndDate != null) data['recurrence_end_date'] = recurrenceEndDate.toIso8601String();
      if (recurrenceDays != null) data['recurrence_days'] = recurrenceDays;
      if (reminders != null) data['reminders'] = reminders.map((r) => r.toJson()).toList();
      if (attendees != null) data['attendees'] = attendees.map((a) => a.toJson()).toList();
      if (color != null) data['color'] = color;
      if (tags != null) data['tags'] = tags;
      if (metadata != null) data['metadata'] = metadata;

      final response = await _supabase
          .from('calendar_events')
          .update(data)
          .eq('id', id)
          .select()
          .single();

      final event = CalendarEvent.fromJson(response);

      // Listeyi güncelle
      final index = _events.indexWhere((e) => e.id == id);
      if (index >= 0) {
        _events[index] = event;
        _events.sort((a, b) => a.startTime.compareTo(b.startTime));
        _eventsController.add(_events);
      }

      if (_selected?.id == id) {
        _selected = event;
        _selectedController.add(_selected);
      }

      await _invalidateCache();

      Logger.info('Updated calendar event: $id');
      return event;
    } catch (e) {
      Logger.error('Error updating calendar event: $e');
      rethrow;
    }
  }

  /// Etkinlik sil
  Future<void> delete(String id) async {
    try {
      await _supabase.from('calendar_events').delete().eq('id', id);

      // Listeden kaldır
      _events.removeWhere((e) => e.id == id);
      _eventsController.add(_events);

      if (_selected?.id == id) {
        _selected = null;
        _selectedController.add(_selected);
      }

      await _invalidateCache();

      Logger.info('Deleted calendar event: $id');
    } catch (e) {
      Logger.error('Error deleting calendar event: $e');
      rethrow;
    }
  }

  // ============================================
  // STATUS OPERATIONS
  // ============================================

  /// Etkinliği onayla
  Future<CalendarEvent> confirm(String id) async {
    return update(id, status: CalendarEventStatus.confirmed);
  }

  /// Etkinliği başlat
  Future<CalendarEvent> start(String id) async {
    return update(id, status: CalendarEventStatus.inProgress);
  }

  /// Etkinliği tamamla
  Future<CalendarEvent> complete(String id) async {
    return update(id, status: CalendarEventStatus.completed);
  }

  /// Etkinliği iptal et
  Future<CalendarEvent> cancel(String id) async {
    return update(id, status: CalendarEventStatus.cancelled);
  }

  /// Etkinliği ertele
  Future<CalendarEvent> postpone(String id, DateTime newStartTime, {DateTime? newEndTime}) async {
    return update(
      id,
      status: CalendarEventStatus.postponed,
      startTime: newStartTime,
      endTime: newEndTime,
    );
  }

  // ============================================
  // ATTENDEE OPERATIONS
  // ============================================

  /// Katılımcı ekle
  Future<CalendarEvent> addAttendee(String eventId, EventAttendee attendee) async {
    final event = await getById(eventId);
    if (event == null) {
      throw Exception('Calendar event not found');
    }

    final attendees = [...event.attendees, attendee];
    return update(eventId, attendees: attendees);
  }

  /// Katılımcı durumunu güncelle
  Future<CalendarEvent> updateAttendeeStatus(
    String eventId,
    String userId,
    AttendeeStatus status,
  ) async {
    final event = await getById(eventId);
    if (event == null) {
      throw Exception('Calendar event not found');
    }

    final attendees = event.attendees.map((a) {
      if (a.userId == userId) {
        return EventAttendee(
          userId: a.userId,
          userName: a.userName,
          email: a.email,
          status: status,
          isRequired: a.isRequired,
          respondedAt: DateTime.now(),
          note: a.note,
        );
      }
      return a;
    }).toList();

    return update(eventId, attendees: attendees);
  }

  /// Katılımcı kaldır
  Future<CalendarEvent> removeAttendee(String eventId, String userId) async {
    final event = await getById(eventId);
    if (event == null) {
      throw Exception('Calendar event not found');
    }

    final attendees = event.attendees.where((a) => a.userId != userId).toList();
    return update(eventId, attendees: attendees);
  }

  // ============================================
  // REMINDER OPERATIONS
  // ============================================

  /// Hatırlatıcı ekle
  Future<CalendarEvent> addReminder(String eventId, EventReminder reminder) async {
    final event = await getById(eventId);
    if (event == null) {
      throw Exception('Calendar event not found');
    }

    final reminders = [...event.reminders, reminder];
    return update(eventId, reminders: reminders);
  }

  /// Hatırlatıcı kaldır
  Future<CalendarEvent> removeReminder(String eventId, String reminderId) async {
    final event = await getById(eventId);
    if (event == null) {
      throw Exception('Calendar event not found');
    }

    final reminders = event.reminders.where((r) => r.id != reminderId).toList();
    return update(eventId, reminders: reminders);
  }

  // ============================================
  // STATISTICS
  // ============================================

  /// İstatistikleri getir
  Future<CalendarStats> getStats({
    String? siteId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (_currentTenantId == null) {
      throw Exception('Tenant context is not set');
    }

    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);

      var query = _supabase
          .from('calendar_events')
          .select('status, type')
          .eq('tenant_id', _currentTenantId!);

      if (siteId != null) {
        query = query.eq('site_id', siteId);
      }

      final response = await query;
      final data = response as List;

      int total = data.length;
      int completed = 0;
      int maintenance = 0;
      int meetings = 0;

      for (final item in data) {
        final status = CalendarEventStatus.fromString(item['status'] as String?);
        final type = CalendarEventType.fromString(item['type'] as String?);

        if (status == CalendarEventStatus.completed) completed++;
        if (type == CalendarEventType.maintenance) maintenance++;
        if (type == CalendarEventType.meeting) meetings++;
      }

      // Bu ay için ayrı sorgu
      final thisMonthQuery = await _supabase
          .from('calendar_events')
          .select('id')
          .eq('tenant_id', _currentTenantId!)
          .gte('start_time', monthStart.toIso8601String())
          .lte('start_time', monthEnd.toIso8601String());

      final thisMonth = (thisMonthQuery as List).length;

      // Gelecek etkinlikler
      final upcomingQuery = await _supabase
          .from('calendar_events')
          .select('id')
          .eq('tenant_id', _currentTenantId!)
          .gte('start_time', now.toIso8601String())
          .inFilter('status', ['SCHEDULED', 'CONFIRMED']);

      final upcoming = (upcomingQuery as List).length;

      return CalendarStats(
        totalEvents: total,
        thisMonthEvents: thisMonth,
        upcomingEvents: upcoming,
        completedEvents: completed,
        maintenanceEvents: maintenance,
        meetingEvents: meetings,
      );
    } catch (e) {
      Logger.error('Error fetching calendar stats: $e');
      rethrow;
    }
  }

  // ============================================
  // PRIVATE METHODS
  // ============================================

  /// Filtreleri uygula
  List<CalendarEvent> _applyFilters({
    CalendarEventType? type,
    CalendarEventStatus? status,
  }) {
    var filtered = _events;

    if (type != null) {
      filtered = filtered.where((e) => e.type == type).toList();
    }

    if (status != null) {
      filtered = filtered.where((e) => e.status == status).toList();
    }

    return filtered;
  }

  /// Cache'i temizle
  Future<void> _invalidateCache() async {
    if (_currentTenantId != null) {
      final pattern = 'calendar_events_$_currentTenantId';
      await _cacheManager.deleteWhere((key) => key.startsWith(pattern));
    }
  }

  /// Seçili etkinliği ayarla
  void selectEvent(CalendarEvent? event) {
    _selected = event;
    _selectedController.add(_selected);
  }

  /// Temizle
  void dispose() {
    _eventsController.close();
    _selectedController.close();
  }
}
