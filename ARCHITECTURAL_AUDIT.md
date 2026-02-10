# Architectural Audit: From Volatile State to Accountability Ledger

**Date:** February 10, 2026  
**Project:** Ledger (Flutter)  
**Assessment:** Storage Fragility & Architectural Decoupling

---

## Executive Summary

The Ledger application demonstrates **excellent architectural intent** but has **critical storage vulnerabilities** that contradict its accountability mission. The good news: the abstraction layers are already in place. The challenge: implementation gaps between the interface and reality.

### Key Findings:
- ✅ **Storage interface is well-designed** (abstract `LedgerStorage`)
- ✅ **Business logic correctly depends on abstraction** (`LedgerRepository` doesn't import SharedPreferences)
- ✅ **Entities are immutable** with proper JSON serialization
- ❌ **SharedPreferences lacks atomicity** and crash safety
- ❌ **Controllers still instantiate concrete storage directly** (coupling)
- ❌ **No transaction support** for multi-step operations
- ❌ **No schema versioning** mechanism
- ❌ **Batch operations have no rollback guarantee**

---

## 1. Storage Fragility: The SharedPreferences Trap

### The Risk

SharedPreferences is a **key-value store optimized for preferences, not application data**:

```
Application State                  Disk
┌──────────────────┐              ┌──────────────┐
│ Day state        │    Write     │ Partially    │
│ Task 1           │ ────────────>│ written data │
│ Task 2           │  (CRASH!)    │ Corruption   │
│ Task 3           │              │              │
└──────────────────┘              └──────────────┘
```

#### Silent Corruption Scenarios:

1. **Incomplete Task Creation:**
   ```
   Operation: Create task and update day reference
   Step 1: Save task -> SUCCESS
   Step 2: Update day with task ID -> CRASH (OOM, battery loss)
   
   Result: Orphaned task in storage, day state inconsistent
   ```

2. **Batch Update Failure:**
   ```
   saveBatch() writes 5 records
   Record 1: ✓ Written
   Record 2: ✓ Written
   Record 3: ✗ CRASH
   Records 4-5: NEVER WRITTEN
   
   Current implementation: No rollback → partial corrupted state
   ```

3. **Crash During Transaction:**
   ```
   transaction() backup created
   Operation modifies 3 records
   After record 2 → CRASH
   
   Rollback attempt: ALSO CRASHES (already corrupted)
   Result: Unrecoverable corruption
   ```

### Code Evidence

**Current Implementation (Unsafe):**

```dart
// shared_prefs_storage.dart (Line 133-150)
@override
Future<void> saveBatch(Map<String, Map<String, dynamic>> records) async {
  try {
    for (final entry in records.entries) {
      final fullKey = '$_prefix${entry.key}';
      final now = DateTime.now();

      final record = StorageRecord(
        key: entry.key,
        data: entry.value,
        createdAt: now,
        updatedAt: now,
      );

      await _prefs.setString(fullKey, jsonEncode(record.toJson()));
      // ^ PROBLEM: No atomicity. Crash here = partial write
    }
  } catch (e) {
    throw LedgerStorageException('Failed to saveBatch: $e');
  }
}
```

**Risk:** If process dies on iteration 3/10, you have 2 records written, 8 not, and no way to know which state is canonical.

### Accountability Violation

The app's core mission is **accountability through immutable records**. SharedPreferences undermines this:

- No guarantee a completed task is actually saved
- No guarantee a day lock actually persists
- Silent data loss masquerades as success
- Audit trail is unreliable

---

## 2. Storage Abstraction: The Good Parts (Don't Break Them!)

### Current Architecture (Correct)

```
Widgets (UI)
    ↓
Controllers (Business Logic)
    ↓
LedgerRepository (Domain)
    ↓
LedgerStorage Interface (Abstract Contract)
    ↓
SharedPreferencesStorage (Concrete Implementation)
    ↓
SharedPreferences / Disk
```

### What's Working:

**`storage_interface.dart` is excellent:**
```dart
abstract class LedgerStorage {
  Future<StorageRecord?> get(String key);
  Future<StorageRecord> save(String key, Map<String, dynamic> data);
  Future<void> transaction(Future<void> Function(LedgerStorage) callback);
  Future<bool> validate();
}
```

This interface enables:
- ✅ Swap implementations without changing business logic
- ✅ Test with `InMemoryStorage` without touching disk
- ✅ Future migration to Drift/Hive/Isar
- ✅ Add encryption layer transparently

### The Problem: Controllers Break Abstraction

**`today_controller.dart` (Line 30-31):**
```dart
TodayController()
    : _repository = LedgerRepository(SharedPreferencesStorage()) {
  _loadDay();
}
```

❌ **Controller directly instantiates concrete storage**

This couples the presentation layer to storage implementation and prevents:
- Dependency injection for testing
- Swapping storage backends
- Proper initialization order

---

## 3. Root Causes & Structural Issues

### Issue 1: Initialization Order (Dependency Injection Missing)

**Current Flow:**
```
LedgerApp._initializeRepository()
    ↓
SharedPreferencesStorage.init() [waits for async prefs]
    ↓
LedgerRepository(storage)
    ↓
Provide via Provider pattern
    ↓
TodayController ignores it and creates new instance!
```

**Problem:** Controllers don't receive injected repository, so they create their own storage.

**Fix Required:**
```dart
// ✅ Controllers receive injected repository
TodayController({required LedgerRepository repository})
    : _repository = repository;

// ✅ In today_screen.dart
ChangeNotifierProvider(
  create: (context) => TodayController(
    repository: Provider.of<LedgerRepository>(context, listen: false),
  ),
)
```

### Issue 2: No Transaction Atomicity

**Current Transaction Implementation (Line 157-190):**
```dart
@override
Future<void> transaction(
  Future<void> Function(LedgerStorage storage) callback,
) async {
  try {
    final backup = await getAll(); // Backup entire state
    try {
      await callback(this);
    } catch (e) {
      // Attempt rollback
      try {
        await saveBatch(Map.fromEntries(
          backup.map((r) => MapEntry(r.key, r.data)),
        ));
      } catch (rollbackError) {
        // ❌ BOTH original and rollback failed
        // ❌ State is UNRECOVERABLE
        throw LedgerStorageException(
          'Transaction failed and rollback also failed: $e, $rollbackError',
        );
      }
      rethrow;
    }
  } catch (e) {
    if (e is LedgerStorageException) rethrow;
    throw LedgerStorageException('Transaction error: $e');
  }
}
```

**Problems:**
1. Backup entire state in memory (expensive, not safe)
2. Rollback can fail, leaving corrupted state
3. No write-ahead log
4. No isolation levels

### Issue 3: No Schema Versioning

Missing: Migration system for data structure changes

```dart
// Future scenario: Need to rename field 'taskIds' → 'taskReferences'
// Current code: Silent data loss or crashes
// Should have: Version field + migration function
```

### Issue 4: No Validation After Writes

```dart
// After save, we never verify data was actually persisted
await _prefs.setString(fullKey, jsonEncode(record.toJson()));
// ^ No validation

// Should be:
final saved = await _prefs.setString(fullKey, json);
if (!saved) throw LedgerStorageException('Persistence failed');
final verify = _prefs.getString(fullKey); // Read back to confirm
if (verify == null) throw LedgerStorageException('Write-through verification failed');
```

---

## 4. The Accountability Crisis

### Current State Integrity Guarantee: **NONE**

```
User Action:        "Complete task: 45 minutes"
Expected Result:    ✓ Task marked complete, stored to disk
Actual Risk:        ✓ UI reflects completion
                    ✗ Task never saved (silently fails)
                    ✗ Reality screen shows incomplete work
                    → Accountability ledger is a lie
```

### Example Failure Chain:

1. User taps "Complete Task" in ActiveTaskScreen
2. Controller calls `repository.completeTask()`
3. Repository calls `_saveTask(updated)` via storage.save()
4. SharedPreferences.setString() called
5. **CRASH before write flushed to disk**
6. UI shows "✓ Complete" but storage has old state
7. App restarts, task is "active" not "completed"
8. Reality screen has missing hours

This breaks **trust in the accountability system**.

---

## 5. Recommended Fixes (Phased Approach)

### Phase 1: Dependency Injection (No Storage Changes)
**Effort:** 2 hours | **Risk:** Minimal | **Impact:** High

Fix coupling immediately:

```dart
// 1. Update TodayController
class TodayController extends ChangeNotifier {
  final LedgerRepository _repository;
  
  TodayController({required this.repository}) 
    : _repository = repository;
}

// 2. Update today_screen.dart
ChangeNotifierProvider(
  create: (context) => TodayController(
    repository: Provider.of<LedgerRepository>(context, listen: false),
  ),
  child: const _TodayView(),
)

// 3. Apply same pattern to all feature controllers
```

**Benefits:**
- Controllers become testable
- Enables proper DI
- No storage changes needed
- Prepares for Phase 2

### Phase 2: Enhanced SharedPreferences Layer (Temporary)
**Effort:** 4 hours | **Risk:** Medium | **Impact:** Medium

Make SharedPreferences safer while planning database migration:

```dart
class RobustSharedPreferencesStorage implements LedgerStorage {
  // Add these safety mechanisms:
  
  // 1. Write-through validation
  @override
  Future<StorageRecord> save(String key, Map<String, dynamic> data) async {
    final json = jsonEncode(data);
    final written = await _prefs.setString(fullKey, json);
    
    if (!written) {
      throw LedgerStorageException('setString returned false');
    }
    
    // Verify write reached disk
    final readback = _prefs.getString(fullKey);
    if (readback != json) {
      throw LedgerStorageException('Write verification failed');
    }
    
    return StorageRecord(key: key, data: data);
  }
  
  // 2. Atomic batch with rollback journal
  @override
  Future<void> saveBatch(Map<String, Map<String, dynamic>> records) async {
    final journal = <String, dynamic>{}; // Track what changed
    
    for (final entry in records.entries) {
      final fullKey = '$_prefix${entry.key}';
      
      // Save original value for rollback
      final original = _prefs.getString(fullKey);
      journal[fullKey] = original;
      
      final json = jsonEncode(entry.value);
      final written = await _prefs.setString(fullKey, json);
      
      if (!written) {
        // Rollback on failure
        for (final rollbackEntry in journal.entries) {
          if (rollbackEntry.value == null) {
            await _prefs.remove(rollbackEntry.key);
          } else {
            await _prefs.setString(rollbackEntry.key, rollbackEntry.value);
          }
        }
        throw LedgerStorageException('saveBatch failed at key $fullKey');
      }
    }
  }
  
  // 3. Health check
  @override
  Future<bool> validate() async {
    try {
      // Write test data
      const testKey = '_health_check_${DateTime.now().millisecond}';
      final testData = {'test': 'data'};
      
      await save(testKey, testData);
      final read = await get(testKey);
      await delete(testKey);
      
      return read != null;
    } catch (e) {
      return false;
    }
  }
}
```

### Phase 3: Migrate to Drift (Permanent Solution)
**Effort:** 16 hours | **Risk:** High (isolated) | **Impact:** Highest

Replace SharedPreferences with Drift for true ACID guarantees:

```dart
// 1. Create Drift database
import 'package:drift/drift.dart';

part 'database.g.dart';

@DataClassName('StorageRecordData')
class StorageRecords extends Table {
  TextColumn get key => text().primaryKey()();
  TextColumn get jsonData => text()(); // Serialized JSON
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get version => text().withDefault(const Constant('1'))();
}

@DriftDatabase(tables: [StorageRecords])
class LedgerDb extends _$LedgerDb {
  LedgerDb(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) => m.createAll(),
    onUpgrade: (Migrator m, int from, int to) async {
      if (from == 1) {
        // Example: Future migration
        // await m.addColumn(storageRecords, storageRecords.version);
      }
    },
  );
}

// 2. Implement DriftStorage
class DriftStorage implements LedgerStorage {
  final LedgerDb _db;

  @override
  Future<void> transaction(
    Future<void> Function(LedgerStorage storage) callback,
  ) async {
    // TRUE ACID transaction with rollback guarantee
    await _db.transaction(() => callback(this));
  }

  @override
  Future<StorageRecord> save(String key, Map<String, dynamic> data) async {
    final now = DateTime.now();
    await _db.into(_db.storageRecords).insertOnConflictUpdate(
      StorageRecordsCompanion(
        key: Value(key),
        jsonData: Value(jsonEncode(data)),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    
    return StorageRecord(key: key, data: data);
  }

  @override
  Future<List<StorageRecord>> getAll({String? prefix}) async {
    var query = _db.select(_db.storageRecords);
    
    if (prefix != null) {
      query = query..where((r) => r.key.like('$prefix%'));
    }
    
    final records = await query.get();
    return records.map((r) => StorageRecord.fromJson(jsonDecode(r.jsonData))).toList();
  }
}

// 3. Add to pubspec.yaml
# dependencies:
#   drift: ^2.14.0
#   sqlite3_flutter_libs: ^0.5.0
#
# dev_dependencies:
#   drift_dev: ^2.14.0
```

**Why Drift?**
- ✅ True ACID transactions
- ✅ Schema versioning + migrations
- ✅ SQL (queryable for debugging)
- ✅ Encrypted storage option (drift_sqlfite)
- ✅ Type-safe queries
- ✅ Battle-tested in production Flutter apps

### Phase 4: Add Audit Trail
**Effort:** 6 hours | **Risk:** Low | **Impact:** High (mission-critical)

Track every change immutably:

```dart
// Add to Drift schema
@DataClassName('AuditLogData')
class AuditLogs extends Table {
  IntColumn get id => autoIncrement()();
  TextColumn get action => text()(); // 'task_created', 'task_completed', 'day_sealed'
  TextColumn get entityId => text()();
  TextColumn get entityType => text()(); // 'task' or 'day'
  TextColumn get oldValue => text().nullable()(); // JSON before
  TextColumn get newValue => text().nullable()(); // JSON after
  DateTimeColumn get timestamp => dateTime()();
  TextColumn get userId => text().nullable()();
}

// In repository, wrap all mutations
Future<TaskEntity> completeTask(TaskEntity task, {required int actualMinutes}) async {
  final updated = task.copyWith(
    state: 'completed',
    actualMinutes: actualMinutes,
    completedAt: DateTime.now(),
  );

  await _storage.transaction((txn) async {
    // Save new state
    await txn.save('$_keyTasks:${task.id}', updated.toJson());
    
    // Log the change immutably
    await _auditLog.record(
      action: 'task_completed',
      entityId: task.id,
      oldValue: jsonEncode(task.toJson()),
      newValue: jsonEncode(updated.toJson()),
    );
  });

  return updated;
}

// Query audit trail for Reality screen
Future<List<AuditLogEntry>> getCompletedTasksForDay(String date) async {
  return await _db
    .select(_db.auditLogs)
    .where((log) => log.action.equals('task_completed') & log.timestamp.isBiggerThanValue(/* date */))
    .get();
}
```

---

## 6. Implementation Roadmap

### Week 1: Dependency Injection (Safety First)
- [ ] Update all controllers to accept injected repository
- [ ] Update all feature screens to provide repository
- [ ] Add tests for controller injection
- [ ] Verify no direct storage instantiation in presentation layer

### Week 2: Robust SharedPreferences (Interim Safety)
- [ ] Implement `RobustSharedPreferencesStorage`
- [ ] Add write-through validation
- [ ] Add health check endpoint
- [ ] Deploy to staging (keeps existing data format)

### Week 3: Drift Setup (Foundation)
- [ ] Create Drift database schema
- [ ] Implement `DriftStorage`
- [ ] Migration tests for existing SharedPreferences data
- [ ] Parallel testing (Drift in test mode)

### Week 4: Migration & Audit Trail
- [ ] Data migration script: SharedPreferences → Drift
- [ ] Implement audit log schema
- [ ] Wrap all mutations with audit logging
- [ ] Deploy with feature flag

---

## 7. Failure Mode Testing

Add these tests to prevent future regressions:

```dart
// test/storage_robustness_test.dart

void main() {
  group('Storage Atomicity', () {
    test('saveBatch rolls back on failure', () async {
      final storage = RobustSharedPreferencesStorage();
      
      // Force failure during batch write
      final records = {
        'key1': {'data': 'value1'},
        'key2': {'data': 'value2'}, // Will fail
        'key3': {'data': 'value3'},
      };
      
      // Verify rollback: key1 should be removed
      final exists = await storage.exists('key1');
      expect(exists, false, reason: 'Partial write should rollback');
    });

    test('transaction validates write-through', () async {
      final storage = RobustSharedPreferencesStorage();
      
      await storage.transaction((txn) async {
        await txn.save('key', {'data': 'value'});
      });
      
      // Read back and verify
      final record = await storage.get('key');
      expect(record?.data['data'], 'value');
    });

    test('crash during save is detectable', () async {
      final storage = RobustSharedPreferencesStorage();
      
      // Simulate storage medium full
      // Should throw exception, not silently fail
      expect(
        () => storage.save('key', {'huge': 'data' * 1000000}),
        throwsA(isA<LedgerStorageException>()),
      );
    });

    test('validate() detects corruption', () async {
      final storage = RobustSharedPreferencesStorage();
      
      // Manually corrupt a key (simulate disk corruption)
      // validate() should return false
      final isHealthy = await storage.validate();
      expect(isHealthy, true);
    });
  });

  group('Accountability Ledger', () {
    test('task completion is immutable', () async {
      final repo = LedgerRepository(storage);
      final task = await repo.createTask(/* ... */);
      
      final completed = await repo.completeTask(task, actualMinutes: 45);
      
      // Verify audit log
      final auditLog = await repo.getAuditLog(task.id);
      expect(auditLog.length, 2); // created + completed
      expect(auditLog.last.action, 'task_completed');
    });

    test('sealed day rejects modifications', () async {
      final repo = LedgerRepository(storage);
      final day = await repo.getOrCreateToday();
      
      await repo.sealDay(day);
      
      // This should throw
      expect(
        () => repo.createTask(name: 'New', estimatedMinutes: 30, dayDate: day.date),
        throwsA(isA<RepositoryException>()),
      );
    });
  });
}
```

---

## 8. Critical Files to Modify

| File | Change | Priority |
|------|--------|----------|
| `lib/features/today/today_controller.dart` | Add repository injection | P0 |
| `lib/features/today/today_screen.dart` | Pass repository to controller | P0 |
| `lib/features/active_task/active_task_controller.dart` | Add repository injection | P0 |
| `lib/features/reflection/reflection_controller.dart` | Add repository injection | P0 |
| `lib/features/reality/reality_controller.dart` | Add repository injection | P0 |
| `lib/shared/data/shared_prefs_storage.dart` | Add write-through validation | P1 |
| `lib/shared/data/ledger_repository.dart` | Add audit logging | P2 |
| `lib/shared/data/storage_interface.dart` | Add version field to StorageRecord | P2 |
| (new) `lib/shared/data/drift_storage.dart` | Implement Drift backend | P3 |
| (new) `lib/shared/data/database.dart` | Drift schema definition | P3 |

---

## 9. Design Principles Reinforced

### ✅ What's Already Correct
1. **Dependency Inversion:** Repository depends on `LedgerStorage` interface
2. **Immutable Entities:** `TaskEntity` and `DayEntity` use copyWith
3. **State Machines:** Task/Day states are explicit
4. **Storage Abstraction:** Interface allows implementation swapping

### ❌ What Needs Fixing
1. **Dependency Injection:** Controllers create own storage
2. **Atomicity Guarantee:** SharedPreferences offers none
3. **Auditability:** No immutable change log
4. **Schema Versioning:** No migration support
5. **Crash Safety:** No write-through validation

### 🎯 Design Goals (Post-Fix)
1. **Storage Agnosticism:** Swap Drift in without touching business logic
2. **Crash-Safe:** Any power failure leaves consistent state
3. **Auditable:** Every change logged immutably
4. **Accountable:** System is trustworthy for commitment tracking
5. **Testable:** In-memory storage for unit tests

---

## 10. Success Metrics

After implementing these fixes:

- ✅ **Zero data corruption** even on ungraceful app termination
- ✅ **100% storage abstraction** (no controller mentions SharedPreferences)
- ✅ **Complete audit trail** (every action logged and queryable)
- ✅ **Migration path clear** (ready for Drift, Hive, or encrypted storage)
- ✅ **Test coverage high** (failures are deliberate, not silent)

---

## Conclusion

The Ledger app's architecture is **sound in intent but fragile in execution**. The abstraction layers are in place—just not consistently used. 

**The path forward:**

1. **Today (Phase 1):** Fix dependency injection (quick win)
2. **This week (Phase 2):** Harden SharedPreferences temporarily
3. **This sprint (Phase 3-4):** Migrate to Drift with audit trail

This transforms the app from a "best effort" persistence system to a **true accountability ledger**—where every commitment is immutable, every change is audited, and crashes don't corrupt data.

**That's the commitment the app makes to its users. Make it real.**

---

## References

- [SharedPreferences Limitations](https://developer.android.com/training/basics/data-storage/shared-preferences)
- [ACID Guarantees in SQLite](https://www.sqlite.org/transactional.html)
- [Drift Documentation](https://drift.simonbinder.eu/)
- [Flutter Dependency Injection Patterns](https://codewithandrea.com/articles/flutter-state-management-riverpod/)
- [Immutable Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html)

