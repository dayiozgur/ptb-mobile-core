import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  group('CalendarEventType', () {
    test('fromString returns correct type for valid values', () {
      expect(CalendarEventType.fromString('MAINTENANCE'), CalendarEventType.maintenance);
      expect(CalendarEventType.fromString('MEETING'), CalendarEventType.meeting);
      expect(CalendarEventType.fromString('INSPECTION'), CalendarEventType.inspection);
      expect(CalendarEventType.fromString('TRAINING'), CalendarEventType.training);
      expect(CalendarEventType.fromString('DEADLINE'), CalendarEventType.deadline);
      expect(CalendarEventType.fromString('HOLIDAY'), CalendarEventType.holiday);
      expect(CalendarEventType.fromString('REMINDER'), CalendarEventType.reminder);
      expect(CalendarEventType.fromString('TASK'), CalendarEventType.task);
    });

    test('fromString returns other for invalid value', () {
      expect(CalendarEventType.fromString('INVALID'), CalendarEventType.other);
      expect(CalendarEventType.fromString(null), CalendarEventType.other);
    });

    test('value property returns correct string', () {
      expect(CalendarEventType.maintenance.value, 'MAINTENANCE');
      expect(CalendarEventType.meeting.value, 'MEETING');
    });

    test('label property returns Turkish label', () {
      expect(CalendarEventType.maintenance.label, 'Bakım');
      expect(CalendarEventType.meeting.label, 'Toplantı');
    });
  });

  group('CalendarEventStatus', () {
    test('fromString returns correct status', () {
      expect(CalendarEventStatus.fromString('SCHEDULED'), CalendarEventStatus.scheduled);
      expect(CalendarEventStatus.fromString('CONFIRMED'), CalendarEventStatus.confirmed);
      expect(CalendarEventStatus.fromString('IN_PROGRESS'), CalendarEventStatus.inProgress);
      expect(CalendarEventStatus.fromString('COMPLETED'), CalendarEventStatus.completed);
      expect(CalendarEventStatus.fromString('CANCELLED'), CalendarEventStatus.cancelled);
      expect(CalendarEventStatus.fromString('POSTPONED'), CalendarEventStatus.postponed);
    });

    test('fromString returns scheduled for invalid value', () {
      expect(CalendarEventStatus.fromString('INVALID'), CalendarEventStatus.scheduled);
      expect(CalendarEventStatus.fromString(null), CalendarEventStatus.scheduled);
    });

    test('isActive returns correct value', () {
      expect(CalendarEventStatus.scheduled.isActive, true);
      expect(CalendarEventStatus.confirmed.isActive, true);
      expect(CalendarEventStatus.inProgress.isActive, true);
      expect(CalendarEventStatus.completed.isActive, false);
      expect(CalendarEventStatus.cancelled.isActive, false);
      expect(CalendarEventStatus.postponed.isActive, false);
    });
  });

  group('RecurrenceFrequency', () {
    test('fromString returns correct frequency', () {
      expect(RecurrenceFrequency.fromString('NONE'), RecurrenceFrequency.none);
      expect(RecurrenceFrequency.fromString('DAILY'), RecurrenceFrequency.daily);
      expect(RecurrenceFrequency.fromString('WEEKLY'), RecurrenceFrequency.weekly);
      expect(RecurrenceFrequency.fromString('MONTHLY'), RecurrenceFrequency.monthly);
      expect(RecurrenceFrequency.fromString('YEARLY'), RecurrenceFrequency.yearly);
      expect(RecurrenceFrequency.fromString('CUSTOM'), RecurrenceFrequency.custom);
    });

    test('fromString returns none for invalid value', () {
      expect(RecurrenceFrequency.fromString('INVALID'), RecurrenceFrequency.none);
      expect(RecurrenceFrequency.fromString(null), RecurrenceFrequency.none);
    });
  });

  group('CalendarEvent', () {
    late CalendarEvent event;
    late DateTime startTime;
    late DateTime endTime;

    setUp(() {
      startTime = DateTime(2025, 6, 15, 10, 0);
      endTime = DateTime(2025, 6, 15, 12, 0);

      event = CalendarEvent(
        id: 'event-123',
        title: 'Test Meeting',
        description: 'A test meeting description',
        type: CalendarEventType.meeting,
        status: CalendarEventStatus.scheduled,
        startTime: startTime,
        endTime: endTime,
        isAllDay: false,
        tenantId: 'tenant-123',
        createdById: 'user-123',
        createdAt: DateTime.now(),
        location: 'Conference Room A',
        meetingUrl: 'https://meet.example.com/abc',
        attendees: [
          EventAttendee(
            userId: 'user-456',
            userName: 'John Doe',
            email: 'john@example.com',
            status: AttendeeStatus.accepted,
          ),
        ],
        reminders: [
          EventReminder(
            id: 'reminder-1',
            minutesBefore: 15,
            type: ReminderType.notification,
          ),
        ],
        tags: ['important', 'team'],
      );
    });

    test('creates instance with required fields', () {
      expect(event.id, 'event-123');
      expect(event.title, 'Test Meeting');
      expect(event.type, CalendarEventType.meeting);
      expect(event.status, CalendarEventStatus.scheduled);
      expect(event.tenantId, 'tenant-123');
    });

    test('duration calculation is correct', () {
      expect(event.duration, const Duration(hours: 2));
    });

    test('durationFormatted returns correct string', () {
      expect(event.durationFormatted, '2 saat 0 dk');

      // Test with shorter duration
      final shortEvent = event.copyWith(
        endTime: startTime.add(const Duration(minutes: 30)),
      );
      expect(shortEvent.durationFormatted, '30 dk');
    });

    test('isPast returns correct value', () {
      final pastEvent = event.copyWith(
        startTime: DateTime.now().subtract(const Duration(days: 1)),
        endTime: DateTime.now().subtract(const Duration(hours: 22)),
      );
      expect(pastEvent.isPast, true);

      final futureEvent = event.copyWith(
        startTime: DateTime.now().add(const Duration(days: 1)),
      );
      expect(futureEvent.isPast, false);
    });

    test('isFuture returns correct value', () {
      final futureEvent = event.copyWith(
        startTime: DateTime.now().add(const Duration(days: 1)),
      );
      expect(futureEvent.isFuture, true);

      final pastEvent = event.copyWith(
        startTime: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(pastEvent.isFuture, false);
    });

    test('isRecurring returns correct value', () {
      expect(event.isRecurring, false);

      final recurringEvent = event.copyWith(recurrence: RecurrenceFrequency.weekly);
      expect(recurringEvent.isRecurring, true);
    });

    test('isOnlineMeeting returns correct value', () {
      expect(event.isOnlineMeeting, true);

      final noUrlEvent = event.copyWith(meetingUrl: null);
      expect(noUrlEvent.isOnlineMeeting, false);
    });

    test('hasLocation returns correct value', () {
      expect(event.hasLocation, true);

      final noLocationEvent = event.copyWith(location: null);
      expect(noLocationEvent.hasLocation, false);
    });

    test('hasAttendees returns correct value', () {
      expect(event.hasAttendees, true);

      final noAttendeesEvent = CalendarEvent(
        id: 'event-456',
        title: 'Solo Event',
        startTime: startTime,
        tenantId: 'tenant-123',
        createdById: 'user-123',
        createdAt: DateTime.now(),
      );
      expect(noAttendeesEvent.hasAttendees, false);
    });

    test('confirmedAttendeesCount is correct', () {
      expect(event.confirmedAttendeesCount, 1);
    });

    test('fromJson creates correct instance', () {
      final json = {
        'id': 'event-789',
        'title': 'JSON Test Event',
        'description': 'Created from JSON',
        'type': 'MAINTENANCE',
        'status': 'CONFIRMED',
        'start_time': '2025-06-20T14:00:00.000Z',
        'end_time': '2025-06-20T16:00:00.000Z',
        'is_all_day': false,
        'tenant_id': 'tenant-456',
        'created_by_id': 'user-789',
        'created_at': '2025-06-10T10:00:00.000Z',
        'location': 'Building B',
        'tags': ['maintenance', 'scheduled'],
        'reminders': [],
        'attendees': [],
        'metadata': {'custom': 'value'},
      };

      final parsed = CalendarEvent.fromJson(json);

      expect(parsed.id, 'event-789');
      expect(parsed.title, 'JSON Test Event');
      expect(parsed.type, CalendarEventType.maintenance);
      expect(parsed.status, CalendarEventStatus.confirmed);
      expect(parsed.location, 'Building B');
      expect(parsed.tags, ['maintenance', 'scheduled']);
      expect(parsed.metadata['custom'], 'value');
    });

    test('toJson creates correct map', () {
      final json = event.toJson();

      expect(json['id'], 'event-123');
      expect(json['title'], 'Test Meeting');
      expect(json['type'], 'MEETING');
      expect(json['status'], 'SCHEDULED');
      expect(json['tenant_id'], 'tenant-123');
      expect(json['location'], 'Conference Room A');
      expect(json['meeting_url'], 'https://meet.example.com/abc');
      expect(json['tags'], ['important', 'team']);
    });

    test('copyWith creates new instance with updated fields', () {
      final updated = event.copyWith(
        title: 'Updated Title',
        status: CalendarEventStatus.confirmed,
      );

      expect(updated.title, 'Updated Title');
      expect(updated.status, CalendarEventStatus.confirmed);
      expect(updated.id, event.id); // Unchanged
      expect(updated.type, event.type); // Unchanged
    });

    test('equality is based on id', () {
      final sameId = CalendarEvent(
        id: 'event-123',
        title: 'Different Title',
        startTime: startTime,
        tenantId: 'tenant-123',
        createdById: 'user-123',
        createdAt: DateTime.now(),
      );

      expect(event == sameId, true);
      expect(event.hashCode, sameId.hashCode);
    });
  });

  group('EventReminder', () {
    test('formattedTime returns correct string', () {
      expect(
        EventReminder(id: '1', minutesBefore: 15).formattedTime,
        '15 dakika önce',
      );
      expect(
        EventReminder(id: '2', minutesBefore: 60).formattedTime,
        '1 saat önce',
      );
      expect(
        EventReminder(id: '3', minutesBefore: 1440).formattedTime,
        '1 gün önce',
      );
    });

    test('fromJson and toJson work correctly', () {
      final json = {
        'id': 'reminder-1',
        'minutes_before': 30,
        'type': 'EMAIL',
        'sent': false,
      };

      final reminder = EventReminder.fromJson(json);
      expect(reminder.id, 'reminder-1');
      expect(reminder.minutesBefore, 30);
      expect(reminder.type, ReminderType.email);
      expect(reminder.sent, false);

      final output = reminder.toJson();
      expect(output['minutes_before'], 30);
      expect(output['type'], 'EMAIL');
    });
  });

  group('EventAttendee', () {
    test('fromJson and toJson work correctly', () {
      final json = {
        'user_id': 'user-123',
        'user_name': 'Jane Doe',
        'email': 'jane@example.com',
        'status': 'ACCEPTED',
        'is_required': true,
      };

      final attendee = EventAttendee.fromJson(json);
      expect(attendee.userId, 'user-123');
      expect(attendee.userName, 'Jane Doe');
      expect(attendee.status, AttendeeStatus.accepted);
      expect(attendee.isRequired, true);

      final output = attendee.toJson();
      expect(output['user_id'], 'user-123');
      expect(output['status'], 'ACCEPTED');
    });
  });

  group('AttendeeStatus', () {
    test('fromString returns correct status', () {
      expect(AttendeeStatus.fromString('PENDING'), AttendeeStatus.pending);
      expect(AttendeeStatus.fromString('ACCEPTED'), AttendeeStatus.accepted);
      expect(AttendeeStatus.fromString('DECLINED'), AttendeeStatus.declined);
      expect(AttendeeStatus.fromString('TENTATIVE'), AttendeeStatus.tentative);
      expect(AttendeeStatus.fromString('INVALID'), AttendeeStatus.pending);
    });
  });

  group('ReminderType', () {
    test('fromString returns correct type', () {
      expect(ReminderType.fromString('NOTIFICATION'), ReminderType.notification);
      expect(ReminderType.fromString('EMAIL'), ReminderType.email);
      expect(ReminderType.fromString('SMS'), ReminderType.sms);
      expect(ReminderType.fromString('INVALID'), ReminderType.notification);
    });
  });

  group('CalendarStats', () {
    test('fromJson creates correct instance', () {
      final json = {
        'total_events': 100,
        'this_month_events': 25,
        'upcoming_events': 10,
        'completed_events': 50,
        'maintenance_events': 30,
        'meeting_events': 20,
      };

      final stats = CalendarStats.fromJson(json);

      expect(stats.totalEvents, 100);
      expect(stats.thisMonthEvents, 25);
      expect(stats.upcomingEvents, 10);
      expect(stats.completedEvents, 50);
      expect(stats.maintenanceEvents, 30);
      expect(stats.meetingEvents, 20);
    });

    test('default values are zero', () {
      const stats = CalendarStats();
      expect(stats.totalEvents, 0);
      expect(stats.thisMonthEvents, 0);
    });
  });
}
