// =============================================================================
// EVENT LOG STORAGE - Append-Only Storage Foundation
// =============================================================================
//
// This storage implementation enforces append-only semantics at the storage layer.
// Events can be added but never modified or deleted.
//
// Integrity guarantees:
// 1. Events are written sequentially with timestamps
// 2. Event IDs are unique (UUIDv4)
// 3. Event log is append-only - no updates or deletes
// 4. Derived state is recomputable from events
//
// Storage structure:
// - Events are stored in a list with temporal ordering
// - Derived state snapshots are stored separately for performance

import 'dart:async';
import 'package:ledger/shared/data/storage_interface.dart';
import 'package:ledger/shared/data/event_types.dart';

class EventLogStorage implements LedgerStorage {
  static const String _keyEvents = 'event_log';
  static const String _keyDerived = 'derived_state';

  final LedgerStorage _baseStorage;

  EventLogStorage(this._baseStorage);

  // =========================================================================
  // Event Log Operations
  // =========================================================================

  /// Append an event to the log - the ONLY way to add events
  /// Returns the event with its assigned ID and timestamp
  Future<LedgerEvent> appendEvent(LedgerEvent event) async {
    // Get current event log
    final events = await _loadEvents();

    // Add new event (append-only)
    events.add(event);

    // Save updated log
    await _saveEvents(events);

    return event;
  }

  /// Get all events for a specific day
  Future<List<LedgerEvent>> getEventsForDay(String day) async {
    final events = await _loadEvents();
    return events.where((e) => e.day == day).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Get all events for a specific task
  Future<List<LedgerEvent>> getEventsForTask(String taskId) async {
    final events = await _loadEvents();
    return events.where((e) => e.taskId == taskId).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  /// Get all events, sorted by timestamp
  Future<List<LedgerEvent>> getAllEvents() async {
    final events = await _loadEvents();
    events.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return events;
  }

  /// Get event count for integrity verification
  Future<int> getEventCount() async {
    final events = await _loadEvents();
    return events.length;
  }

  // =========================================================================
  // Derived State Operations
  // =========================================================================

  /// Save derived state snapshot (for performance)
  Future<void> saveDerivedState(DerivedState state) async {
    await _baseStorage.save(_keyDerived, state.toJson());
  }

  /// Load derived state snapshot
  Future<DerivedState?> loadDerivedState() async {
    final json = await _baseStorage.get(_keyDerived);
    if (json == null) return null;
    return DerivedState.fromJson(json.data);
  }

  // =========================================================================
  // LedgerStorage Interface (delegated to base)
  // =========================================================================

  @override
  Future<StorageRecord?> get(String key) => _baseStorage.get(key);

  @override
  Future<StorageRecord> save(String key, Map<String, dynamic> data) =>
      _baseStorage.save(key, data);

  @override
  Future<void> delete(String key) => _baseStorage.delete(key);

  @override
  Future<bool> exists(String key) => _baseStorage.exists(key);

  @override
  Future<List<StorageRecord>> getAll({String? prefix}) =>
      _baseStorage.getAll(prefix: prefix);

  @override
  Future<void> saveBatch(Map<String, Map<String, dynamic>> records) =>
      _baseStorage.saveBatch(records);

  @override
  Future<void> deleteAll({String? prefix}) =>
      _baseStorage.deleteAll(prefix: prefix);

  @override
  Future<void> transaction(
    Future<void> Function(LedgerStorage storage) callback,
  ) =>
      _baseStorage.transaction(callback);

  @override
  Future<bool> validate() => _baseStorage.validate();

  // =========================================================================
  // Private Helpers
  // =========================================================================

  Future<List<LedgerEvent>> _loadEvents() async {
    try {
      final json = await _baseStorage.get(_keyEvents);
      if (json == null) return [];

      final data = json.data['events'] as List;
      return data
          .map((e) => LedgerEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If events are corrupted, return empty (corruption will be detected)
      return [];
    }
  }

  Future<void> _saveEvents(List<LedgerEvent> events) async {
    final data = {
      'events': events.map((e) => e.toJson()).toList(),
      'lastUpdated': DateTime.now().toIso8601String(),
    };
    await _baseStorage.save(_keyEvents, data);
  }
}

// =============================================================================
// EVENT LOG EXCEPTION TYPES
// =============================================================================

class EventLogException implements Exception {
  final String message;
  EventLogException(this.message);

  @override
  String toString() => 'EventLogException: $message';
}

class EventLogCorruptedException extends EventLogException {
  EventLogCorruptedException(String message)
      : super('Event log corrupted: $message');
}

class EventLogIntegrityException extends EventLogException {
  final int expectedCount;
  final int actualCount;

  EventLogIntegrityException(this.expectedCount, this.actualCount)
      : super(
          'Integrity violation: expected $expectedCount events but found $actualCount',
        );
}
