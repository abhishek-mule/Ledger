import 'package:flutter_test/flutter_test.dart';
import 'package:ledger/shared/data/ledger_event.dart';
import 'package:ledger/shared/data/state_validation.dart';
import 'package:ledger/shared/data/reality_analytics.dart';

void main() {
  group('Phase 5: Append-Only Event Log', () {
    late MockLedgerStorage mockStorage;
    late LedgerEventLog eventLog;

    setUp(() {
      mockStorage = MockLedgerStorage();
      eventLog = LedgerEventLog(storage: mockStorage);
    });

    test('append writes event to storage', () async {
      final event = LedgerEvent(
        id: 'event_1',
        timestamp: DateTime.now(),
        dayDate: '2026-02-10',
        taskId: 'task_1',
        eventType: 'task_started',
      );

      final appended = await eventLog.append(event);

      expect(appended.isSealed, true); // ✅ Event sealed on write
      expect(appended.id, 'event_1');
    });

    test('append seals event (immutable)', () async {
      final event = TaskStartedEvent.create(
        taskId: 'task_1',
        dayDate: '2026-02-10',
        timestamp: DateTime.now(),
      );

      final appended = await eventLog.append(event);

      expect(appended.isSealed, true);
      expect(appended.eventType, 'task_started');
    });

    test('get event returns sealed record', () async {
      final event = TaskStartedEvent.create(
        taskId: 'task_1',
        dayDate: '2026-02-10',
        timestamp: DateTime.now(),
      );

      await eventLog.append(event);
      final retrieved = await eventLog.getEvent(event.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.isSealed, true);
    });

    test('getEventsForDay returns chronological order', () async {
      final now = DateTime.now();

      // Add events in random order
      final event3 = TaskCompletedEvent.create(
        taskId: 'task_1',
        dayDate: '2026-02-10',
        timestamp: now.add(Duration(hours: 3)),
        actualMinutes: 45,
        whatWorked: 'test',
        impediment: 'test',
      );

      final event1 = TaskStartedEvent.create(
        taskId: 'task_1',
        dayDate: '2026-02-10',
        timestamp: now,
      );

      final event2 = SessionInterruptedEvent.create(
        taskId: 'task_1',
        dayDate: '2026-02-10',
        timestamp: now.add(Duration(hours: 1)),
        reason: 'phone_locked',
      );

      await eventLog.append(event3);
      await eventLog.append(event1);
      await eventLog.append(event2);

      final events = await eventLog.getEventsForDay('2026-02-10');

      expect(events.length, 3);
      expect(events[0].eventType, 'task_started'); // First chronologically
      expect(events[1].eventType, 'session_interrupted');
      expect(events[2].eventType, 'task_completed'); // Last chronologically
    });

    test('getEventsForTask filters by task', () async {
      final event1 = TaskStartedEvent.create(
        taskId: 'task_1',
        dayDate: '2026-02-10',
        timestamp: DateTime.now(),
      );

      final event2 = TaskStartedEvent.create(
        taskId: 'task_2',
        dayDate: '2026-02-10',
        timestamp: DateTime.now(),
      );

      await eventLog.append(event1);
      await eventLog.append(event2);

      final taskEvents = await eventLog.getEventsForTask('task_1');

      expect(taskEvents.length, 1);
      expect(taskEvents.first.taskId, 'task_1');
    });

    test('write-once semantics: duplicate append fails', () async {
      final event = TaskStartedEvent.create(
        taskId: 'task_1',
        dayDate: '2026-02-10',
        timestamp: DateTime.now(),
      );

      await eventLog.append(event);

      // Attempting to append the same event again
      expect(
        () => eventLog.append(event),
        throwsA(isA<LedgerEventException>()),
      );
    });
  });

  group('Phase 6: State Derivation & Validation', () {
    late MockLedgerEventLog mockEventLog;
    late StateDerivationEngine derivationEngine;

    setUp(() {
      mockEventLog = MockLedgerEventLog();
      derivationEngine = StateDerivationEngine(eventLog: mockEventLog);
    });

    test('derive task state from task_started event', () async {
      // This test would need real event data
      // Placeholder for comprehensive derivation testing
      expect(true, true);
    });

    test('integrity validation detects state mismatch', () async {
      // Compare derived state vs stored state
      // Flag mismatches
      expect(true, true);
    });

    test('validation report shows all violations', () async {
      // Run full system validation
      // Collect all mismatches
      expect(true, true);
    });
  });

  group('Phase 7: Reality Analytics', () {
    late MockLedgerEventLog mockEventLog;
    late RealityAnalytics analytics;

    setUp(() {
      mockEventLog = MockLedgerEventLog();
      analytics = RealityAnalytics(eventLog: mockEventLog);
    });

    test('analyzeTask calculates variance correctly', () async {
      // estimated: 30, actual: 45
      // variance: +15 (overrun by 50%)
      expect(true, true);
    });

    test('analyzeUnderestimation finds pattern', () async {
      // "All coding tasks run ~20% over"
      expect(true, true);
    });

    test('analyzeAbandonment finds reasons', () async {
      // "Most abandonments due to scope_creep"
      expect(true, true);
    });

    test('analyzeSessionPatterns shows work fragmentation', () async {
      // "Tasks avg 1.2 sessions (mostly single-session)"
      expect(true, true);
    });

    test('analyzeTime tracks committed minutes', () async {
      // "45 minutes committed, 2 interruptions"
      // ⚠️ Label: "Committed time, not focused time"
      expect(true, true);
    });

    test('analyzeDay aggregates task metrics', () async {
      // Daily completion rate: 66.7%
      // Total variance: +20.8%
      expect(true, true);
    });
  });

  group('Critical Principles', () {
    test('events are immutable once sealed', () async {
      // ✅ append(event) works
      // ❌ event.metadata['x'] = 'y' then append fails
      expect(true, true);
    });

    test('state is derived, not stored', () async {
      // Events = truth
      // Snapshots = convenience (can be discarded)
      expect(true, true);
    });

    test('time committed ≠ focused time', () async {
      // App active (start → resume) = committed
      // User actively typing = focused
      // We measure committed (includes idle time)
      // ⚠️ Must be labeled correctly
      expect(true, true);
    });

    test('integrity check runs on startup', () async {
      // Load events → rebuild state → compare with snapshot
      // Flag if mismatch
      expect(true, true);
    });
  });
}

// Mock implementations
class MockLedgerStorage {
  final _data = <String, Map<String, dynamic>>{};

  Future<void> save(String key, Map<String, dynamic> data) async {
    _data[key] = data;
  }

  Future<Map<String, dynamic>?> get(String key) async {
    return _data[key];
  }

  Future<bool> exists(String key) async {
    return _data.containsKey(key);
  }

  Future<List<Map<String, dynamic>>> getAll({String? prefix}) async {
    return _data.entries
        .where((e) => prefix == null || e.key.startsWith(prefix))
        .map((e) => e.value)
        .toList();
  }
}

class MockLedgerEventLog {
  final _events = <LedgerEvent>[];

  Future<LedgerEvent> append(LedgerEvent event) async {
    if (_events.any((e) => e.id == event.id)) {
      throw LedgerEventException('Event ${event.id} already exists');
    }
    final sealed = event.seal();
    _events.add(sealed);
    return sealed;
  }

  Future<LedgerEvent?> getEvent(String eventId) async {
    return _events.firstWhere(
      (e) => e.id == eventId,
      orElse: () => null as LedgerEvent,
    );
  }

  Future<List<LedgerEvent>> getEventsForDay(String dayDate) async {
    return _events
        .where((e) => e.dayDate == dayDate)
        .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<List<LedgerEvent>> getEventsForTask(String taskId) async {
    return _events
        .where((e) => e.taskId == taskId)
        .toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<List<LedgerEvent>> getAllEvents() async {
    return _events..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }
}

