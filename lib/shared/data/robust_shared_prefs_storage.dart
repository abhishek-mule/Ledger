import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledger/shared/data/storage_interface.dart';

// =============================================================================
// ROBUST SHARED PREFERENCES STORAGE - Interim Safety Layer
// =============================================================================
//
// This is a temporary hardened version of SharedPreferencesStorage.
// It adds:
//   - Write-through validation (read after write)
//   - Atomic batch operations with rollback journal
//   - Health check and corruption detection
//   - Better error reporting
//
// This is NOT a permanent solution. Plan migration to Drift (Phase 3-4).
//
// Why temporary?
// - SharedPreferences lacks true ACID guarantees
// - No crash safety if process dies mid-write
// - No transaction isolation levels
// - Drift will replace this eventually
//
// Why use this now?
// - Better than current implementation
// - No app-level logic changes needed
// - Safety improvements are transparent
// - Gives time to plan Drift migration

class RobustSharedPreferencesStorage implements LedgerStorage {
  final SharedPreferences _prefs;
  final String _prefix;

  // Health tracking
  int _writeAttempts = 0;
  int _writeFailures = 0;

  RobustSharedPreferencesStorage._(this._prefs, this._prefix);

  factory RobustSharedPreferencesStorage() {
    return _instance;
  }

  static late final RobustSharedPreferencesStorage _instance;

  static Future<RobustSharedPreferencesStorage> init() async {
    final prefs = await SharedPreferences.getInstance();
    _instance = RobustSharedPreferencesStorage._(prefs, 'ledger_');
    return _instance;
  }

  // =========================================================================
  // Single Record Operations (with write-through validation)
  // =========================================================================

  @override
  Future<StorageRecord?> get(String key) async {
    try {
      final fullKey = '$_prefix$key';
      final json = _prefs.getString(fullKey);

      if (json == null) return null;

      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        return StorageRecord.fromJson(data);
      } catch (e) {
        throw LedgerStorageException(
          'Corrupted data for $key: unable to decode JSON. $e',
        );
      }
    } catch (e) {
      if (e is LedgerStorageException) rethrow;
      throw LedgerStorageException('Failed to read $key: $e');
    }
  }

  @override
  Future<StorageRecord> save(String key, Map<String, dynamic> data) async {
    _writeAttempts++;

    try {
      final fullKey = '$_prefix$key';
      final now = DateTime.now();

      final record = StorageRecord(
        key: key,
        data: data,
        createdAt: now,
        updatedAt: now,
      );

      final json = jsonEncode(record.toJson());

      // WRITE-THROUGH VALIDATION:
      // 1. Write to storage
      // 2. Read back to confirm
      // 3. Compare values

      final writeSuccess = await _prefs.setString(fullKey, json);

      if (!writeSuccess) {
        _writeFailures++;
        throw LedgerStorageException(
          'setString($key) returned false. Storage may be full or corrupted.',
        );
      }

      // Verify write reached storage (write-through validation)
      final readback = _prefs.getString(fullKey);
      if (readback != json) {
        _writeFailures++;
        throw LedgerStorageException(
          'Write verification failed for $key. Read back value does not match written value.',
        );
      }

      return record;
    } catch (e) {
      if (e is LedgerStorageException) rethrow;
      _writeFailures++;
      throw LedgerStorageException('Failed to save $key: $e');
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      final fullKey = '$_prefix$key';

      // Verify key exists before deletion
      if (!_prefs.containsKey(fullKey)) {
        throw LedgerStorageException('Cannot delete $key: key does not exist');
      }

      final success = await _prefs.remove(fullKey);

      if (!success) {
        throw LedgerStorageException('remove($key) returned false');
      }

      // Verify deletion
      if (_prefs.containsKey(fullKey)) {
        throw LedgerStorageException('Delete verification failed for $key');
      }
    } catch (e) {
      if (e is LedgerStorageException) rethrow;
      throw LedgerStorageException('Failed to delete $key: $e');
    }
  }

  @override
  Future<bool> exists(String key) async {
    try {
      final fullKey = '$_prefix$key';
      return _prefs.containsKey(fullKey);
    } catch (e) {
      throw LedgerStorageException('Failed to check existence of $key: $e');
    }
  }

  // =========================================================================
  // Batch Operations (with atomic rollback)
  // =========================================================================

  @override
  Future<List<StorageRecord>> getAll({String? prefix}) async {
    try {
      final targetPrefix = prefix != null ? '$_prefix$prefix' : _prefix;
      final records = <StorageRecord>[];
      final corruptedKeys = <String>[];

      for (final key in _prefs.getKeys()) {
        if (key.startsWith(targetPrefix)) {
          final json = _prefs.getString(key);
          if (json != null) {
            try {
              final data = jsonDecode(json) as Map<String, dynamic>;
              records.add(StorageRecord.fromJson(data));
            } catch (e) {
              // Track but don't fail - allow reading consistent data
              corruptedKeys.add(key);
            }
          }
        }
      }

      // If we found corrupted records, log warning
      if (corruptedKeys.isNotEmpty) {
        print('[LedgerStorage] WARNING: Found ${corruptedKeys.length} corrupted records: $corruptedKeys');
      }

      return records;
    } catch (e) {
      throw LedgerStorageException('Failed to getAll: $e');
    }
  }

  @override
  Future<void> saveBatch(Map<String, Map<String, dynamic>> records) async {
    // ATOMIC BATCH WITH ROLLBACK:
    // Save original values so we can rollback on failure

    final journal = <String, String?>{}; // Track original values
    final keysWritten = <String>[];

    try {
      // Collect original values (rollback journal)
      for (final entry in records.entries) {
        final fullKey = '$_prefix${entry.key}';
        final originalJson = _prefs.getString(fullKey);
        journal[fullKey] = originalJson;
      }

      // Write all new values
      for (final entry in records.entries) {
        final fullKey = '$_prefix${entry.key}';
        final now = DateTime.now();

        final record = StorageRecord(
          key: entry.key,
          data: entry.value,
          createdAt: now,
          updatedAt: now,
        );

        final json = jsonEncode(record.toJson());

        // Write with verification
        final success = await _prefs.setString(fullKey, json);

        if (!success) {
          throw LedgerStorageException('saveBatch: setString failed at key ${entry.key}');
        }

        // Verify write
        final readback = _prefs.getString(fullKey);
        if (readback != json) {
          throw LedgerStorageException(
            'saveBatch: write verification failed at key ${entry.key}',
          );
        }

        keysWritten.add(fullKey);
      }
    } catch (e) {
      // ROLLBACK: Restore original values
      try {
        for (final fullKey in keysWritten) {
          if (journal[fullKey] == null) {
            await _prefs.remove(fullKey);
          } else {
            await _prefs.setString(fullKey, journal[fullKey]!);
          }
        }
        // After rollback, throw original error
        throw LedgerStorageException('saveBatch failed and rolled back: $e');
      } catch (rollbackError) {
        // Rollback itself failed - CRITICAL ERROR
        throw LedgerStorageException(
          'saveBatch FAILED CRITICALLY: Original error: $e, Rollback error: $rollbackError',
        );
      }
    }
  }

  @override
  Future<void> deleteAll({String? prefix}) async {
    try {
      final targetPrefix = prefix != null ? '$_prefix$prefix' : _prefix;
      final keysToDelete = <String>[];

      for (final key in _prefs.getKeys()) {
        if (key.startsWith(targetPrefix)) {
          keysToDelete.add(key);
        }
      }

      for (final key in keysToDelete) {
        final success = await _prefs.remove(key);
        if (!success) {
          throw LedgerStorageException('Failed to delete $key');
        }
      }

      // Verify all deleted
      final remaining = _prefs.getKeys()
          .where((k) => k.startsWith(targetPrefix))
          .toList();

      if (remaining.isNotEmpty) {
        throw LedgerStorageException(
          'deleteAll verification failed: ${remaining.length} keys remain',
        );
      }
    } catch (e) {
      if (e is LedgerStorageException) rethrow;
      throw LedgerStorageException('Failed to deleteAll: $e');
    }
  }

  // =========================================================================
  // Transaction Support (best-effort)
  // =========================================================================

  @override
  Future<void> transaction(
    Future<void> Function(LedgerStorage storage) callback,
  ) async {
    // SharedPreferences doesn't support true transactions.
    // This is best-effort with rollback journal.

    try {
      // Create snapshot of current state for rollback
      final backup = await getAll();

      try {
        // Execute callback
        await callback(this);
      } catch (e) {
        // Attempt rollback
        try {
          // Clear all ledger data
          await deleteAll();

          // Restore from backup
          await saveBatch(
            Map.fromEntries(
              backup.map((r) => MapEntry(r.key, r.data)),
            ),
          );
        } catch (rollbackError) {
          // Rollback failed - UNRECOVERABLE STATE
          throw LedgerStorageException(
            'Transaction failed (error: $e) and rollback also failed (error: $rollbackError). '
            'Storage may be in inconsistent state. Manual repair may be required.',
          );
        }

        // Transaction failed but was rolled back
        rethrow;
      }
    } catch (e) {
      if (e is LedgerStorageException) rethrow;
      throw LedgerStorageException('Transaction error: $e');
    }
  }

  // =========================================================================
  // Health Check & Validation
  // =========================================================================

  @override
  Future<bool> validate() async {
    try {
      // Health check: write test data, read back, delete
      const testKey = '_health_check_${DateTime.now().millisecond}';
      final testData = {'timestamp': DateTime.now().toIso8601String()};

      // Write
      await save(testKey, testData);

      // Read
      final read = await get(testKey);
      if (read == null) {
        print('[LedgerStorage] HEALTH CHECK FAILED: Written data not readable');
        return false;
      }

      // Delete
      await delete(testKey);

      // Verify deletion
      final deleted = await get(testKey);
      if (deleted != null) {
        print('[LedgerStorage] HEALTH CHECK FAILED: Deleted data still readable');
        return false;
      }

      return true;
    } catch (e) {
      print('[LedgerStorage] HEALTH CHECK FAILED: $e');
      return false;
    }
  }

  // =========================================================================
  // Diagnostics
  // =========================================================================

  /// Get health diagnostics
  Map<String, dynamic> getDiagnostics() {
    final allKeys = _prefs.getKeys();
    final ledgerKeys = allKeys.where((k) => k.startsWith(_prefix)).length;

    return {
      'type': 'RobustSharedPreferencesStorage',
      'totalKeys': allKeys.length,
      'ledgerKeys': ledgerKeys,
      'writeAttempts': _writeAttempts,
      'writeFailures': _writeFailures,
      'failureRate': _writeAttempts > 0
          ? (_writeFailures / _writeAttempts * 100).toStringAsFixed(1) + '%'
          : 'N/A',
      'healthy': _writeFailures == 0,
      'note': 'This is a temporary hardened storage. Plan migration to Drift for Phase 3-4.',
    };
  }
}

// =============================================================================
// EXCEPTION TYPES
// =============================================================================

class LedgerStorageException implements Exception {
  final String message;

  LedgerStorageException(this.message);

  @override
  String toString() => 'LedgerStorageException: $message';
}





