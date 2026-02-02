/// Takvim etkinliği tipi
enum CalendarEventType {
  /// Bakım planı
  maintenance('MAINTENANCE', 'Bakım'),

  /// Toplantı
  meeting('MEETING', 'Toplantı'),

  /// Denetim
  inspection('INSPECTION', 'Denetim'),

  /// Eğitim
  training('TRAINING', 'Eğitim'),

  /// Son tarih (deadline)
  deadline('DEADLINE', 'Son Tarih'),

  /// Tatil
  holiday('HOLIDAY', 'Tatil'),

  /// Hatırlatıcı
  reminder('REMINDER', 'Hatırlatıcı'),

  /// Görev
  task('TASK', 'Görev'),

  /// Diğer
  other('OTHER', 'Diğer');

  final String value;
  final String label;
  const CalendarEventType(this.value, this.label);

  static CalendarEventType fromString(String? value) {
    return CalendarEventType.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => CalendarEventType.other,
    );
  }
}

/// Etkinlik durumu
enum CalendarEventStatus {
  /// Planlandı
  scheduled('SCHEDULED', 'Planlandı'),

  /// Onaylandı
  confirmed('CONFIRMED', 'Onaylandı'),

  /// Devam ediyor
  inProgress('IN_PROGRESS', 'Devam Ediyor'),

  /// Tamamlandı
  completed('COMPLETED', 'Tamamlandı'),

  /// İptal edildi
  cancelled('CANCELLED', 'İptal Edildi'),

  /// Ertelendi
  postponed('POSTPONED', 'Ertelendi');

  final String value;
  final String label;
  const CalendarEventStatus(this.value, this.label);

  static CalendarEventStatus fromString(String? value) {
    return CalendarEventStatus.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => CalendarEventStatus.scheduled,
    );
  }

  /// Aktif mi?
  bool get isActive => this == scheduled || this == confirmed || this == inProgress;
}

/// Tekrar sıklığı
enum RecurrenceFrequency {
  /// Tekrar yok
  none('NONE', 'Tekrar Yok'),

  /// Günlük
  daily('DAILY', 'Günlük'),

  /// Haftalık
  weekly('WEEKLY', 'Haftalık'),

  /// Aylık
  monthly('MONTHLY', 'Aylık'),

  /// Yıllık
  yearly('YEARLY', 'Yıllık'),

  /// Özel
  custom('CUSTOM', 'Özel');

  final String value;
  final String label;
  const RecurrenceFrequency(this.value, this.label);

  static RecurrenceFrequency fromString(String? value) {
    return RecurrenceFrequency.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => RecurrenceFrequency.none,
    );
  }
}

/// Takvim Etkinliği modeli
///
/// Bakım planları, toplantılar, denetimler ve diğer
/// zamanlanmış olayları temsil eder.
class CalendarEvent {
  /// Benzersiz ID
  final String id;

  /// Etkinlik başlığı
  final String title;

  /// Açıklama
  final String? description;

  /// Etkinlik tipi
  final CalendarEventType type;

  /// Durum
  final CalendarEventStatus status;

  // ============================================
  // ZAMAN BİLGİLERİ
  // ============================================

  /// Başlangıç tarihi ve saati
  final DateTime startTime;

  /// Bitiş tarihi ve saati
  final DateTime? endTime;

  /// Tüm gün etkinliği mi?
  final bool isAllDay;

  /// Timezone
  final String? timezone;

  // ============================================
  // TEKRAR (RECURRENCE)
  // ============================================

  /// Tekrar sıklığı
  final RecurrenceFrequency recurrence;

  /// Tekrar aralığı (her X gün/hafta/ay)
  final int? recurrenceInterval;

  /// Tekrar bitiş tarihi
  final DateTime? recurrenceEndDate;

  /// Tekrar sayısı (toplam kaç kez)
  final int? recurrenceCount;

  /// Hangi günler (haftalık tekrar için: 0=Pazar, 6=Cumartesi)
  final List<int>? recurrenceDays;

  /// Üst etkinlik ID (tekrarlanan serinin parent'ı)
  final String? parentEventId;

  /// RRULE string (iCal uyumlu)
  final String? rrule;

  // ============================================
  // HATIRLATICILAR
  // ============================================

  /// Hatırlatıcılar
  final List<EventReminder> reminders;

  // ============================================
  // KONUM BİLGİLERİ
  // ============================================

  /// Konum adı
  final String? location;

  /// Konum adresi
  final String? locationAddress;

  /// Enlem
  final double? latitude;

  /// Boylam
  final double? longitude;

  /// Online meeting URL
  final String? meetingUrl;

  // ============================================
  // İLİŞKİLER
  // ============================================

  /// Tenant ID
  final String tenantId;

  /// Organization ID
  final String? organizationId;

  /// Site ID
  final String? siteId;

  /// Unit ID
  final String? unitId;

  /// Controller ID (bakım planı için)
  final String? controllerId;

  /// Work Request ID (bağlı talep)
  final String? workRequestId;

  // ============================================
  // KATILIMCILAR
  // ============================================

  /// Oluşturan kullanıcı ID
  final String createdById;

  /// Katılımcılar
  final List<EventAttendee> attendees;

  // ============================================
  // GÖRSEL
  // ============================================

  /// Renk (hex)
  final String? color;

  /// İkon adı
  final String? icon;

  // ============================================
  // EK BİLGİLER
  // ============================================

  /// Etiketler
  final List<String> tags;

  /// Ek özellikler (JSON)
  final Map<String, dynamic> metadata;

  // ============================================
  // ZAMAN DAMGALARI
  // ============================================

  /// Oluşturulma tarihi
  final DateTime createdAt;

  /// Güncellenme tarihi
  final DateTime? updatedAt;

  /// Oluşturan kullanıcı
  final String? createdBy;

  /// Güncelleyen kullanıcı
  final String? updatedBy;

  const CalendarEvent({
    required this.id,
    required this.title,
    this.description,
    this.type = CalendarEventType.other,
    this.status = CalendarEventStatus.scheduled,
    required this.startTime,
    this.endTime,
    this.isAllDay = false,
    this.timezone,
    this.recurrence = RecurrenceFrequency.none,
    this.recurrenceInterval,
    this.recurrenceEndDate,
    this.recurrenceCount,
    this.recurrenceDays,
    this.parentEventId,
    this.rrule,
    this.reminders = const [],
    this.location,
    this.locationAddress,
    this.latitude,
    this.longitude,
    this.meetingUrl,
    required this.tenantId,
    this.organizationId,
    this.siteId,
    this.unitId,
    this.controllerId,
    this.workRequestId,
    required this.createdById,
    this.attendees = const [],
    this.color,
    this.icon,
    this.tags = const [],
    this.metadata = const {},
    required this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  // ============================================
  // COMPUTED PROPERTIES
  // ============================================

  /// Süre
  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  /// Süre formatlanmış
  String get durationFormatted {
    final d = duration;
    if (d == null) return '-';
    if (d.inMinutes < 60) return '${d.inMinutes} dk';
    if (d.inHours < 24) return '${d.inHours} saat ${d.inMinutes % 60} dk';
    return '${d.inDays} gün';
  }

  /// Geçmiş mi?
  bool get isPast {
    final compareTime = endTime ?? startTime;
    return compareTime.isBefore(DateTime.now());
  }

  /// Devam ediyor mu?
  bool get isOngoing {
    final now = DateTime.now();
    if (now.isBefore(startTime)) return false;
    if (endTime != null && now.isAfter(endTime!)) return false;
    return true;
  }

  /// Gelecekte mi?
  bool get isFuture => startTime.isAfter(DateTime.now());

  /// Bugün mü?
  bool get isToday {
    final now = DateTime.now();
    return startTime.year == now.year &&
        startTime.month == now.month &&
        startTime.day == now.day;
  }

  /// Tekrarlanan mı?
  bool get isRecurring => recurrence != RecurrenceFrequency.none;

  /// Tekrar serisinin bir parçası mı?
  bool get isPartOfSeries => parentEventId != null;

  /// Online toplantı mı?
  bool get isOnlineMeeting => meetingUrl != null && meetingUrl!.isNotEmpty;

  /// Konum var mı?
  bool get hasLocation => location != null && location!.isNotEmpty;

  /// Katılımcı var mı?
  bool get hasAttendees => attendees.isNotEmpty;

  /// Onaylanmış katılımcı sayısı
  int get confirmedAttendeesCount =>
      attendees.where((a) => a.status == AttendeeStatus.accepted).length;

  /// Aktif mi?
  bool get isActive => status.isActive && !isPast;

  // ============================================
  // JSON SERIALIZATION
  // ============================================

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      type: CalendarEventType.fromString(json['type'] as String?),
      status: CalendarEventStatus.fromString(json['status'] as String?),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] != null
          ? DateTime.tryParse(json['end_time'] as String)
          : null,
      isAllDay: json['is_all_day'] as bool? ?? false,
      timezone: json['timezone'] as String?,
      recurrence: RecurrenceFrequency.fromString(json['recurrence'] as String?),
      recurrenceInterval: json['recurrence_interval'] as int?,
      recurrenceEndDate: json['recurrence_end_date'] != null
          ? DateTime.tryParse(json['recurrence_end_date'] as String)
          : null,
      recurrenceCount: json['recurrence_count'] as int?,
      recurrenceDays: json['recurrence_days'] != null
          ? List<int>.from(json['recurrence_days'] as List)
          : null,
      parentEventId: json['parent_event_id'] as String?,
      rrule: json['rrule'] as String?,
      reminders: json['reminders'] != null
          ? (json['reminders'] as List)
              .map((e) => EventReminder.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      location: json['location'] as String?,
      locationAddress: json['location_address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      meetingUrl: json['meeting_url'] as String?,
      tenantId: json['tenant_id'] as String,
      organizationId: json['organization_id'] as String?,
      siteId: json['site_id'] as String?,
      unitId: json['unit_id'] as String?,
      controllerId: json['controller_id'] as String?,
      workRequestId: json['work_request_id'] as String?,
      createdById: json['created_by_id'] as String? ?? json['created_by'] as String? ?? '',
      attendees: json['attendees'] != null
          ? (json['attendees'] as List)
              .map((e) => EventAttendee.fromJson(e as Map<String, dynamic>))
              .toList()
          : const [],
      color: json['color'] as String?,
      icon: json['icon'] as String?,
      tags: json['tags'] != null ? List<String>.from(json['tags'] as List) : const [],
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.value,
      'status': status.value,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'is_all_day': isAllDay,
      'timezone': timezone,
      'recurrence': recurrence.value,
      'recurrence_interval': recurrenceInterval,
      'recurrence_end_date': recurrenceEndDate?.toIso8601String(),
      'recurrence_count': recurrenceCount,
      'recurrence_days': recurrenceDays,
      'parent_event_id': parentEventId,
      'rrule': rrule,
      'reminders': reminders.map((e) => e.toJson()).toList(),
      'location': location,
      'location_address': locationAddress,
      'latitude': latitude,
      'longitude': longitude,
      'meeting_url': meetingUrl,
      'tenant_id': tenantId,
      'organization_id': organizationId,
      'site_id': siteId,
      'unit_id': unitId,
      'controller_id': controllerId,
      'work_request_id': workRequestId,
      'created_by_id': createdById,
      'attendees': attendees.map((e) => e.toJson()).toList(),
      'color': color,
      'icon': icon,
      'tags': tags,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'created_by': createdBy,
      'updated_by': updatedBy,
    };
  }

  // ============================================
  // COPY WITH
  // ============================================

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    CalendarEventType? type,
    CalendarEventStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    String? timezone,
    RecurrenceFrequency? recurrence,
    int? recurrenceInterval,
    DateTime? recurrenceEndDate,
    int? recurrenceCount,
    List<int>? recurrenceDays,
    String? parentEventId,
    String? rrule,
    List<EventReminder>? reminders,
    String? location,
    String? locationAddress,
    double? latitude,
    double? longitude,
    String? meetingUrl,
    String? tenantId,
    String? organizationId,
    String? siteId,
    String? unitId,
    String? controllerId,
    String? workRequestId,
    String? createdById,
    List<EventAttendee>? attendees,
    String? color,
    String? icon,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      timezone: timezone ?? this.timezone,
      recurrence: recurrence ?? this.recurrence,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      recurrenceCount: recurrenceCount ?? this.recurrenceCount,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
      parentEventId: parentEventId ?? this.parentEventId,
      rrule: rrule ?? this.rrule,
      reminders: reminders ?? this.reminders,
      location: location ?? this.location,
      locationAddress: locationAddress ?? this.locationAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      meetingUrl: meetingUrl ?? this.meetingUrl,
      tenantId: tenantId ?? this.tenantId,
      organizationId: organizationId ?? this.organizationId,
      siteId: siteId ?? this.siteId,
      unitId: unitId ?? this.unitId,
      controllerId: controllerId ?? this.controllerId,
      workRequestId: workRequestId ?? this.workRequestId,
      createdById: createdById ?? this.createdById,
      attendees: attendees ?? this.attendees,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }

  @override
  String toString() => 'CalendarEvent($id, $title, ${startTime.toIso8601String()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is CalendarEvent && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Etkinlik hatırlatıcısı
class EventReminder {
  /// Hatırlatıcı ID
  final String id;

  /// Etkinlikten kaç dakika önce
  final int minutesBefore;

  /// Hatırlatma tipi
  final ReminderType type;

  /// Gönderildi mi?
  final bool sent;

  /// Gönderilme tarihi
  final DateTime? sentAt;

  const EventReminder({
    required this.id,
    required this.minutesBefore,
    this.type = ReminderType.notification,
    this.sent = false,
    this.sentAt,
  });

  /// Zamanı formatla
  String get formattedTime {
    if (minutesBefore < 60) return '$minutesBefore dakika önce';
    if (minutesBefore < 1440) return '${minutesBefore ~/ 60} saat önce';
    return '${minutesBefore ~/ 1440} gün önce';
  }

  factory EventReminder.fromJson(Map<String, dynamic> json) {
    return EventReminder(
      id: json['id'] as String,
      minutesBefore: json['minutes_before'] as int,
      type: ReminderType.fromString(json['type'] as String?),
      sent: json['sent'] as bool? ?? false,
      sentAt: json['sent_at'] != null
          ? DateTime.tryParse(json['sent_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'minutes_before': minutesBefore,
      'type': type.value,
      'sent': sent,
      'sent_at': sentAt?.toIso8601String(),
    };
  }
}

/// Hatırlatıcı tipi
enum ReminderType {
  /// Push bildirim
  notification('NOTIFICATION', 'Bildirim'),

  /// Email
  email('EMAIL', 'Email'),

  /// SMS
  sms('SMS', 'SMS');

  final String value;
  final String label;
  const ReminderType(this.value, this.label);

  static ReminderType fromString(String? value) {
    return ReminderType.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => ReminderType.notification,
    );
  }
}

/// Etkinlik katılımcısı
class EventAttendee {
  /// Kullanıcı ID
  final String userId;

  /// Kullanıcı adı
  final String? userName;

  /// Email
  final String? email;

  /// Katılım durumu
  final AttendeeStatus status;

  /// Zorunlu mu?
  final bool isRequired;

  /// Yanıt tarihi
  final DateTime? respondedAt;

  /// Not
  final String? note;

  const EventAttendee({
    required this.userId,
    this.userName,
    this.email,
    this.status = AttendeeStatus.pending,
    this.isRequired = false,
    this.respondedAt,
    this.note,
  });

  factory EventAttendee.fromJson(Map<String, dynamic> json) {
    return EventAttendee(
      userId: json['user_id'] as String,
      userName: json['user_name'] as String?,
      email: json['email'] as String?,
      status: AttendeeStatus.fromString(json['status'] as String?),
      isRequired: json['is_required'] as bool? ?? false,
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'] as String)
          : null,
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'user_name': userName,
      'email': email,
      'status': status.value,
      'is_required': isRequired,
      'responded_at': respondedAt?.toIso8601String(),
      'note': note,
    };
  }
}

/// Katılımcı durumu
enum AttendeeStatus {
  /// Beklemede
  pending('PENDING', 'Beklemede'),

  /// Kabul edildi
  accepted('ACCEPTED', 'Kabul Edildi'),

  /// Reddedildi
  declined('DECLINED', 'Reddedildi'),

  /// Belirsiz
  tentative('TENTATIVE', 'Belirsiz');

  final String value;
  final String label;
  const AttendeeStatus(this.value, this.label);

  static AttendeeStatus fromString(String? value) {
    return AttendeeStatus.values.firstWhere(
      (e) => e.value == value || e.name == value,
      orElse: () => AttendeeStatus.pending,
    );
  }
}

/// Takvim görünümü tipi
enum CalendarViewType {
  /// Gün
  day,

  /// Hafta
  week,

  /// Ay
  month,

  /// Yıl
  year,

  /// Ajanda (liste)
  agenda,
}

/// Takvim istatistikleri
class CalendarStats {
  /// Toplam etkinlik
  final int totalEvents;

  /// Bu ayki etkinlik
  final int thisMonthEvents;

  /// Gelecek etkinlik
  final int upcomingEvents;

  /// Tamamlanan etkinlik
  final int completedEvents;

  /// Bakım etkinlikleri
  final int maintenanceEvents;

  /// Toplantılar
  final int meetingEvents;

  const CalendarStats({
    this.totalEvents = 0,
    this.thisMonthEvents = 0,
    this.upcomingEvents = 0,
    this.completedEvents = 0,
    this.maintenanceEvents = 0,
    this.meetingEvents = 0,
  });

  factory CalendarStats.fromJson(Map<String, dynamic> json) {
    return CalendarStats(
      totalEvents: json['total_events'] as int? ?? 0,
      thisMonthEvents: json['this_month_events'] as int? ?? 0,
      upcomingEvents: json['upcoming_events'] as int? ?? 0,
      completedEvents: json['completed_events'] as int? ?? 0,
      maintenanceEvents: json['maintenance_events'] as int? ?? 0,
      meetingEvents: json['meeting_events'] as int? ?? 0,
    );
  }
}
