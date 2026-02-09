# 📖 API Reference

## İçindekiler

1. [Core Module](#core-module)
2. [Authentication](#authentication)
3. [API Client](#api-client)
4. [Calendar Service](#calendar-service)
5. [Work Request Service](#work-request-service)
6. [Storage](#storage)
7. [Theme](#theme)
8. [Utilities](#utilities)
9. [Widgets](#widgets)

## 🔧 Core Module

### CoreInitializer

Initialize all core services.
```dart
class CoreInitializer {
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
    String? environment,
  })
}
```

**Parameters:**
- `supabaseUrl`: Supabase project URL
- `supabaseAnonKey`: Supabase anonymous key
- `environment`: Environment name (dev/staging/prod)

**Example:**
```dart
await CoreInitializer.initialize(
  supabaseUrl: 'https://xxx.supabase.co',
  supabaseAnonKey: 'eyJxxx...',
  environment: 'production',
);
```

---

## 🔐 Authentication

### AuthService

Main authentication service.
```dart
class AuthService {
  // Sign in with email/password
  Future<AuthResult> signIn({
    required String email,
    required String password,
    String? tenantId,
  })
  
  // Sign up new user
  Future<AuthResult> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  })
  
  // Sign out
  Future<void> signOut()
  
  // Reset password
  Future<void> resetPassword(String email)
  
  // Get current user
  User? get currentUser
  
  // Auth state stream
  Stream<AuthState> get authStateChanges
  
  // Social login
  Future<AuthResult> signInWithGoogle()
  Future<AuthResult> signInWithApple()
  
  // Biometric
  Future<bool> enableBiometric()
  Future<AuthResult> signInWithBiometric()
}
```

**Example:**
```dart
final authService = getIt<AuthService>();

// Email login
final result = await authService.signIn(
  email: 'user@example.com',
  password: 'SecurePass123!',
);

result.when(
  success: (user) => print('Logged in: ${user.email}'),
  failure: (error) => print('Error: $error'),
  requiresTenantSelection: (tenants) => _showTenantPicker(tenants),
);

// Listen to auth changes
authService.authStateChanges.listen((state) {
  if (state.isAuthenticated) {
    // Navigate to home
  } else {
    // Navigate to login
  }
});
```

### AuthResult

Authentication result wrapper.
```dart
class AuthResult {
  static AuthResult success(User user)
  static AuthResult failure(String error)
  static AuthResult requiresTenantSelection(List<Tenant> tenants)
  
  T when<T>({
    required T Function(User) success,
    required T Function(String) failure,
    required T Function(List<Tenant>) requiresTenantSelection,
  })
}
```

### BiometricAuth

Biometric authentication helper.
```dart
class BiometricAuth {
  // Check if biometric is available
  Future<bool> isAvailable()
  
  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics()
  
  // Authenticate
  Future<bool> authenticate({
    required String reason,
    bool stickyAuth = true,
  })
}
```

---

## 🌐 API Client

### ApiClient

Generic HTTP client with Supabase integration.
```dart
class ApiClient {
  // GET request
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    T Function(Map<String, dynamic>)? fromJson,
  })
  
  // POST request
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? data,
    T Function(Map<String, dynamic>)? fromJson,
  })
  
  // PUT request
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, dynamic>? data,
    T Function(Map<String, dynamic>)? fromJson,
  })
  
  // DELETE request
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    T Function(Map<String, dynamic>)? fromJson,
  })
  
  // Supabase query
  Future<List<T>> querySupabase<T>({
    required String table,
    required T Function(Map<String, dynamic>) fromJson,
    String? select,
    PostgrestFilterBuilder Function(PostgrestFilterBuilder)? filter,
  })
}
```

**Example:**
```dart
final apiClient = getIt<ApiClient>();

// REST API call
final response = await apiClient.get<Device>(
  '/api/devices',
  queryParams: {'status': 'online'},
  fromJson: (json) => Device.fromJson(json),
);

response.when(
  success: (device) => print('Device: $device'),
  failure: (error) => print('Error: $error'),
);

// Supabase query
final devices = await apiClient.querySupabase<Device>(
  table: 'devices',
  fromJson: (json) => Device.fromJson(json),
  filter: (query) => query
    .eq('tenant_id', currentTenantId)
    .eq('status', 'online')
    .order('created_at', ascending: false),
);
```

### ApiResponse

API response wrapper.
```dart
class ApiResponse<T> {
  static ApiResponse<T> success<T>(T data)
  static ApiResponse<T> failure<T>(ApiError error)
  
  T when<T>({
    required T Function(T data) success,
    required T Function(ApiError error) failure,
  })
}
```

### Interceptors

Request/response interceptors.
```dart
// Auth Interceptor
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler)
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler)
}

// Tenant Interceptor
class TenantInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler)
}

// Logger Interceptor
class LoggerInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler)
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler)
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler)
}
```

---

## 📅 Calendar Service

### CalendarService

Takvim etkinliklerini yönetir. CRUD operasyonları, tekrarlayan etkinlikler, hatırlatıcılar ve katılımcı yönetimi sağlar.

```dart
class CalendarService {
  // Streams
  Stream<List<CalendarEvent>> get eventsStream
  Stream<CalendarEvent?> get selectedStream

  // Getters
  List<CalendarEvent> get events
  CalendarEvent? get selected
  List<CalendarEvent> get todayEvents
  List<CalendarEvent> get upcomingEvents
  List<CalendarEvent> get maintenanceEvents
  List<CalendarEvent> get meetingEvents

  // Context
  void setTenant(String tenantId)
  void setUser(String userId)
  void clearContext()

  // CRUD
  Future<List<CalendarEvent>> getEvents({
    required DateTime startDate,
    required DateTime endDate,
    String? siteId,
    CalendarEventType? type,
    CalendarEventStatus? status,
    bool forceRefresh = false,
  })

  Future<List<CalendarEvent>> getEventsForMonth(int year, int month, {String? siteId})
  Future<List<CalendarEvent>> getTodayEvents({String? siteId})
  Future<List<CalendarEvent>> getUpcomingEvents({int days = 7, String? siteId})
  Future<CalendarEvent?> getById(String id)

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
  })

  Future<CalendarEvent> update(String id, {...})
  Future<void> delete(String id)

  // Status Operations
  Future<CalendarEvent> confirm(String id)
  Future<CalendarEvent> start(String id)
  Future<CalendarEvent> complete(String id)
  Future<CalendarEvent> cancel(String id)
  Future<CalendarEvent> postpone(String id, DateTime newStartTime, {DateTime? newEndTime})

  // Attendee Operations
  Future<CalendarEvent> addAttendee(String eventId, EventAttendee attendee)
  Future<CalendarEvent> updateAttendeeStatus(String eventId, String userId, AttendeeStatus status)
  Future<CalendarEvent> removeAttendee(String eventId, String userId)

  // Reminder Operations
  Future<CalendarEvent> addReminder(String eventId, EventReminder reminder)
  Future<CalendarEvent> removeReminder(String eventId, String reminderId)

  // Statistics
  Future<CalendarStats> getStats({String? siteId, DateTime? fromDate, DateTime? toDate})

  // Selection
  void selectEvent(CalendarEvent? event)
  void dispose()
}
```

**Example:**
```dart
final calendarService = getIt<CalendarService>();

// Set context
calendarService.setTenant('tenant-123');
calendarService.setUser('user-456');

// Get events for current month
final events = await calendarService.getEventsForMonth(2025, 6);

// Create a maintenance event
final event = await calendarService.create(
  title: 'HVAC Maintenance',
  description: 'Quarterly maintenance check',
  type: CalendarEventType.maintenance,
  startTime: DateTime(2025, 6, 15, 10, 0),
  endTime: DateTime(2025, 6, 15, 12, 0),
  siteId: 'site-123',
  recurrence: RecurrenceFrequency.monthly,
  reminders: [
    EventReminder(id: 'r1', minutesBefore: 60, type: ReminderType.notification),
    EventReminder(id: 'r2', minutesBefore: 1440, type: ReminderType.email),
  ],
  attendees: [
    EventAttendee(userId: 'tech-1', userName: 'John Technician', isRequired: true),
  ],
);

// Update status
await calendarService.confirm(event.id);
await calendarService.start(event.id);
await calendarService.complete(event.id);

// Listen to event changes
calendarService.eventsStream.listen((events) {
  print('Events updated: ${events.length}');
});
```

### CalendarEvent

Takvim etkinliği modeli.
```dart
class CalendarEvent {
  final String id;
  final String title;
  final String? description;
  final CalendarEventType type;
  final CalendarEventStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isAllDay;
  final RecurrenceFrequency recurrence;
  final String? location;
  final String? meetingUrl;
  final String tenantId;
  final String? siteId;
  final String? unitId;
  final List<EventReminder> reminders;
  final List<EventAttendee> attendees;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  // Computed Properties
  Duration? get duration
  String get durationFormatted
  bool get isPast
  bool get isOngoing
  bool get isFuture
  bool get isToday
  bool get isRecurring
  bool get isOnlineMeeting
  bool get hasLocation
  bool get hasAttendees
  int get confirmedAttendeesCount
  bool get isActive
}
```

### CalendarEventType

Etkinlik tipleri.
```dart
enum CalendarEventType {
  maintenance,  // Bakım planı
  meeting,      // Toplantı
  inspection,   // Denetim
  training,     // Eğitim
  deadline,     // Son tarih
  holiday,      // Tatil
  reminder,     // Hatırlatıcı
  task,         // Görev
  other,        // Diğer
}
```

### CalendarEventStatus

Etkinlik durumları.
```dart
enum CalendarEventStatus {
  scheduled,    // Planlandı
  confirmed,    // Onaylandı
  inProgress,   // Devam ediyor
  completed,    // Tamamlandı
  cancelled,    // İptal edildi
  postponed,    // Ertelendi

  bool get isActive  // scheduled, confirmed, inProgress için true
}
```

### RecurrenceFrequency

Tekrar sıklığı.
```dart
enum RecurrenceFrequency {
  none,     // Tekrar yok
  daily,    // Günlük
  weekly,   // Haftalık
  monthly,  // Aylık
  yearly,   // Yıllık
  custom,   // Özel
}
```

### EventReminder

Hatırlatıcı modeli.
```dart
class EventReminder {
  final String id;
  final int minutesBefore;     // 15, 30, 60, 1440 (1 gün)
  final ReminderType type;     // notification, email, sms
  final bool sent;
  final DateTime? sentAt;

  String get formattedTime     // "15 dakika önce", "1 saat önce"
}
```

### EventAttendee

Katılımcı modeli.
```dart
class EventAttendee {
  final String userId;
  final String? userName;
  final String? email;
  final AttendeeStatus status;  // pending, accepted, declined, tentative
  final bool isRequired;
  final DateTime? respondedAt;
  final String? note;
}
```

### CalendarStats

Takvim istatistikleri.
```dart
class CalendarStats {
  final int totalEvents;
  final int thisMonthEvents;
  final int upcomingEvents;
  final int completedEvents;
  final int maintenanceEvents;
  final int meetingEvents;
}
```

---

## 🔧 Work Request Service

### WorkRequestService

İş taleplerini yönetir. CRUD operasyonları, durum geçişleri, atama ve onay işlemleri sağlar.

```dart
class WorkRequestService {
  // Streams
  Stream<List<WorkRequest>> get requestsStream
  Stream<WorkRequest?> get selectedStream

  // Getters
  List<WorkRequest> get requests
  WorkRequest? get selected
  List<WorkRequest> get pendingRequests
  List<WorkRequest> get activeRequests
  List<WorkRequest> get overdueRequests
  List<WorkRequest> get myAssignedRequests
  List<WorkRequest> get myCreatedRequests

  // Context
  void setTenant(String tenantId)
  void setUser(String userId)
  void clearContext()

  // CRUD
  Future<List<WorkRequest>> getAll({
    String? siteId,
    String? unitId,
    WorkRequestStatus? status,
    WorkRequestType? type,
    WorkRequestPriority? priority,
    String? assignedToId,
    DateTime? fromDate,
    DateTime? toDate,
    bool forceRefresh = false,
  })

  Future<WorkRequest?> getById(String id)

  Future<WorkRequest> create({
    required String title,
    String? description,
    WorkRequestType type = WorkRequestType.general,
    WorkRequestPriority priority = WorkRequestPriority.normal,
    String? siteId,
    String? unitId,
    String? controllerId,
    DateTime? expectedCompletionDate,
    int? estimatedDuration,
    double? estimatedCost,
    String? categoryId,
    List<String>? tags,
    Map<String, dynamic>? metadata,
  })

  Future<WorkRequest> update(String id, {...})
  Future<void> delete(String id)

  // Status Transitions
  Future<WorkRequest> submit(String id)           // draft → submitted
  Future<WorkRequest> approve(String id, {String? note})   // submitted → approved
  Future<WorkRequest> reject(String id, {required String reason})
  Future<WorkRequest> assign(String id, {String? assignedToId, String? assignedTeamId})
  Future<WorkRequest> startWork(String id)        // assigned → in_progress
  Future<WorkRequest> putOnHold(String id)        // in_progress → on_hold
  Future<WorkRequest> resume(String id)           // on_hold → in_progress
  Future<WorkRequest> complete(String id, {int? actualDuration, double? actualCost})
  Future<WorkRequest> cancel(String id, {String? reason})
  Future<WorkRequest> close(String id)            // completed → closed

  // Notes
  Future<WorkRequest> addNote(String requestId, {
    required String content,
    WorkRequestNoteType type = WorkRequestNoteType.comment,
  })

  // Statistics
  Future<WorkRequestStats> getStats({String? siteId, DateTime? fromDate, DateTime? toDate})

  // Selection
  void selectRequest(WorkRequest? request)
  void dispose()
}
```

**Example:**
```dart
final workRequestService = getIt<WorkRequestService>();

// Set context
workRequestService.setTenant('tenant-123');
workRequestService.setUser('user-456');

// Create a breakdown request
final request = await workRequestService.create(
  title: 'AC Unit Not Working',
  description: 'Conference room AC stopped cooling',
  type: WorkRequestType.breakdown,
  priority: WorkRequestPriority.high,
  siteId: 'site-123',
  unitId: 'unit-456',
  expectedCompletionDate: DateTime.now().add(Duration(days: 2)),
  estimatedDuration: 120,  // minutes
  estimatedCost: 500.0,
  tags: ['hvac', 'urgent'],
);

// Submit for approval
await workRequestService.submit(request.id);

// Approve and assign
await workRequestService.approve(request.id, note: 'Approved for immediate action');
await workRequestService.assign(request.id, assignedToId: 'technician-789');

// Start work
await workRequestService.startWork(request.id);

// Add progress note
await workRequestService.addNote(
  request.id,
  content: 'Replaced compressor unit',
  type: WorkRequestNoteType.comment,
);

// Complete with actual values
await workRequestService.complete(
  request.id,
  actualDuration: 90,
  actualCost: 450.0,
);

// Get statistics
final stats = await workRequestService.getStats(siteId: 'site-123');
print('Completion rate: ${stats.completionRate}%');

// Filter requests
final overdueRequests = workRequestService.overdueRequests;
final myTasks = workRequestService.myAssignedRequests;
```

### WorkRequest

İş talebi modeli.
```dart
class WorkRequest {
  final String id;
  final String? requestNumber;
  final String title;
  final String? description;
  final WorkRequestType type;
  final WorkRequestStatus status;
  final WorkRequestPriority priority;

  // Talep Bilgileri
  final String requestedById;
  final String? requestedByName;
  final DateTime requestedAt;
  final DateTime? expectedCompletionDate;
  final DateTime? actualCompletionDate;

  // Atama Bilgileri
  final String? assignedToId;
  final String? assignedToName;
  final String? assignedTeamId;
  final DateTime? assignedAt;

  // Onay Bilgileri
  final String? approvedById;
  final DateTime? approvedAt;
  final String? approvalNote;
  final String? rejectionReason;

  // Konum Bilgileri
  final String tenantId;
  final String? siteId;
  final String? siteName;
  final String? unitId;
  final String? unitName;
  final String? controllerId;

  // Süre ve Maliyet
  final int? estimatedDuration;
  final int? actualDuration;
  final double? estimatedCost;
  final double? actualCost;
  final String? currency;

  // Ekler ve Notlar
  final List<WorkRequestAttachment> attachments;
  final List<WorkRequestNote> notes;
  final List<String> tags;
  final Map<String, dynamic> metadata;

  // İlişkiler
  final String? workOrderId;
  final String? parentRequestId;
  final String? alarmId;

  // Computed Properties
  bool get isEditable
  bool get isActionable
  bool get isFinished
  bool get isAssigned
  bool get isApproved
  bool get isOverdue
  Duration? get overdueBy
  String get locationSummary
  String get estimatedDurationFormatted
  String get actualDurationFormatted
  String get costSummary
  bool get hasWorkOrder
  bool get hasAttachments
  bool get hasNotes
  List<WorkRequestStatus> get allowedTransitions
  bool canTransitionTo(WorkRequestStatus newStatus)
}
```

### WorkRequestStatus

Talep durumları ve geçişleri.
```dart
enum WorkRequestStatus {
  draft,        // Taslak - düzenlenebilir
  submitted,    // Gönderildi - onay bekliyor
  approved,     // Onaylandı - atama bekliyor
  rejected,     // Reddedildi - düzenlenebilir
  assigned,     // Atandı - işlem bekliyor
  inProgress,   // Devam ediyor
  onHold,       // Beklemede
  completed,    // Tamamlandı - kapatma bekliyor
  cancelled,    // İptal edildi - final
  closed,       // Kapatıldı - final

  bool get isEditable    // draft, submitted, rejected
  bool get isActionable  // approved, assigned, inProgress
  bool get isFinished    // completed, cancelled, closed
}
```

**Status Transitions (Durum Geçişleri):**
```
draft → submitted → approved → assigned → inProgress → completed → closed
                  ↘ rejected ↗         ↘ onHold ↗

Any → cancelled (iptal herhangi bir durumdan yapılabilir)
```

### WorkRequestType

Talep tipleri.
```dart
enum WorkRequestType {
  breakdown,     // Arıza bildirimi
  maintenance,   // Bakım talebi
  service,       // Servis talebi
  inspection,    // Denetim talebi
  installation,  // Kurulum talebi
  modification,  // Değişiklik talebi
  general,       // Genel talep
}
```

### WorkRequestPriority

Öncelik seviyeleri.
```dart
enum WorkRequestPriority {
  low,       // Düşük (level: 1)
  normal,    // Normal (level: 2)
  high,      // Yüksek (level: 3)
  urgent,    // Acil (level: 4)
  critical,  // Kritik (level: 5)

  int get level
  bool isHigherThan(WorkRequestPriority other)
}
```

### WorkRequestAttachment

Ek dosya modeli.
```dart
class WorkRequestAttachment {
  final String id;
  final String fileName;
  final String fileUrl;
  final int? fileSize;
  final String? mimeType;
  final String? description;
  final String? uploadedById;
  final DateTime uploadedAt;

  String get fileSizeFormatted  // "1.5 MB"
  bool get isImage
}
```

### WorkRequestNote

Not modeli.
```dart
class WorkRequestNote {
  final String id;
  final String content;
  final WorkRequestNoteType type;  // comment, system, statusChange, assignment, approval
  final String authorId;
  final String? authorName;
  final DateTime createdAt;
}
```

### WorkRequestStats

İş talebi istatistikleri.
```dart
class WorkRequestStats {
  final int totalCount;
  final int pendingCount;
  final int activeCount;
  final int completedCount;
  final int overdueCount;
  final Map<WorkRequestPriority, int> byPriority;
  final Map<WorkRequestType, int> byType;

  double get completionRate  // (completedCount / totalCount) * 100
}
```

---

## 💾 Storage

### SecureStorage

Secure key-value storage.
```dart
class SecureStorage {
  // Write
  Future<void> write({
    required String key,
    required String value,
  })
  
  // Read
  Future<String?> read(String key)
  
  // Delete
  Future<void> delete(String key)
  
  // Delete all
  Future<void> deleteAll()
  
  // Check if contains
  Future<bool> containsKey(String key)
}
```

**Example:**
```dart
final storage = getIt<SecureStorage>();

// Save token
await storage.write(
  key: 'access_token',
  value: token,
);

// Read token
final token = await storage.read('access_token');

// Delete token
await storage.delete('access_token');
```

### CacheManager

Cache management with TTL support.
```dart
class CacheManager {
  // Get with cache
  Future<T?> getCached<T>({
    required String key,
    required Future<T> Function() fetchFn,
    required T Function(Map<String, dynamic>) fromJson,
    Duration? ttl,
  })
  
  // Set cache
  Future<void> setCache(
    String key,
    dynamic data, {
    Duration? ttl,
  })
  
  // Invalidate
  Future<void> invalidate(String key)
  
  // Clear all
  Future<void> clearAll()
}
```

**Example:**
```dart
final cache = getIt<CacheManager>();

// Get with automatic caching
final user = await cache.getCached<User>(
  key: 'user_${userId}',
  fetchFn: () => apiClient.getUser(userId),
  fromJson: (json) => User.fromJson(json),
  ttl: Duration(hours: 1),
);

// Manual cache set
await cache.setCache(
  'config',
  configData,
  ttl: Duration(days: 1),
);

// Invalidate
await cache.invalidate('user_${userId}');
```

---

## 🎨 Theme

### AppTheme

Application theme configuration.
```dart
class AppTheme {
  static ThemeData light
  static ThemeData dark
  
  static ThemeData customLight({
    Color? primaryColor,
    Color? accentColor,
  })
  
  static ThemeData customDark({
    Color? primaryColor,
    Color? accentColor,
  })
}
```

### AppColors

Color constants.
```dart
class AppColors {
  // Brand
  static const Color primary
  static const Color secondary
  static const Color accent
  
  // Semantic
  static const Color success
  static const Color warning
  static const Color error
  static const Color info
  
  // Neutral (Light)
  static const Color backgroundLight
  static const Color surfaceLight
  static const Color textPrimaryLight
  static const Color textSecondaryLight
  
  // Neutral (Dark)
  static const Color backgroundDark
  static const Color surfaceDark
  static const Color textPrimaryDark
  static const Color textSecondaryDark
}
```

### AppTypography

Typography styles.
```dart
class AppTypography {
  static const TextStyle largeTitle
  static const TextStyle title1
  static const TextStyle title2
  static const TextStyle title3
  static const TextStyle headline
  static const TextStyle body
  static const TextStyle callout
  static const TextStyle subhead
  static const TextStyle footnote
  static const TextStyle caption1
  static const TextStyle caption2
}
```

### AppSpacing

Spacing constants.
```dart
class AppSpacing {
  static const double xs = 4.0
  static const double sm = 8.0
  static const double md = 16.0
  static const double lg = 24.0
  static const double xl = 32.0
  static const double xxl = 48.0
}
```

---

## 🛠️ Utilities

### Validators

Form validators.
```dart
class Validators {
  // Email validation
  static String? email(String? value)
  
  // Password validation
  static String? password(String? value, {
    int minLength = 8,
    bool requireNumber = true,
    bool requireSpecialChar = true,
  })
  
  // Required field
  static String? required(String? value, {
    String? fieldName,
  })
  
  // Min length
  static String? minLength(String? value, int length)
  
  // Max length
  static String? maxLength(String? value, int length)
  
  // Phone number
  static String? phone(String? value)
  
  // URL
  static String? url(String? value)
}
```

**Example:**
```dart
AppTextField(
  label: 'Email',
  validator: Validators.email,
)

AppTextField(
  label: 'Password',
  validator: (value) => Validators.password(
    value,
    minLength: 12,
    requireSpecialChar: true,
  ),
)
```

### Formatters

Data formatters.
```dart
class Formatters {
  // Currency
  static String currency(
    double amount, {
    String symbol = '\$',
    int decimals = 2,
  })
  
  // Number
  static String number(
    num value, {
    int decimals = 0,
    bool useGrouping = true,
  })
  
  // Percentage
  static String percentage(
    double value, {
    int decimals = 1,
  })
  
  // Date
  static String date(
    DateTime date, {
    String format = 'dd/MM/yyyy',
  })
  
  // Relative time
  static String relativeTime(DateTime date)
  
  // File size
  static String fileSize(int bytes)
}
```

**Example:**
```dart
Formatters.currency(1234.56)           // "$1,234.56"
Formatters.number(1000000)             // "1,000,000"
Formatters.percentage(0.856)           // "85.6%"
Formatters.date(DateTime.now())        // "26/01/2024"
Formatters.relativeTime(yesterday)     // "1 day ago"
Formatters.fileSize(1536000)           // "1.5 MB"
```

### Logger

Logging utility.
```dart
class Logger {
  static void debug(String message)
  static void info(String message)
  static void warning(String message)
  static void error(String message, [Object? error, StackTrace? stackTrace])
}
```

---

## 🧩 Widgets

### AppButton

Primary button component.
```dart
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isFullWidth = false,
    this.icon,
  })
}

enum AppButtonVariant { primary, secondary, tertiary, destructive }
enum AppButtonSize { small, medium, large }
```

### AppTextField

Text input field.
```dart
class AppTextField extends StatelessWidget {
  const AppTextField({
    this.label,
    this.placeholder,
    this.controller,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
  })
}
```

### AppCard

Card container.
```dart
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding,
    this.backgroundColor,
    this.showShadow = true,
    this.showBorder = false,
  })
}
```

### AppListTile

List item.
```dart
class AppListTile extends StatelessWidget {
  const AppListTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showDivider = true,
    this.showChevron = false,
  })
}
```

### AppBottomSheet

Bottom sheet dialog.
```dart
class AppBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isDismissible = true,
    bool showDragHandle = true,
  })
}
```

**Full widget API reference:** See [Component Library](COMPONENT_LIBRARY.md)

---

**Sonraki:** [Component Library →](COMPONENT_LIBRARY.md)