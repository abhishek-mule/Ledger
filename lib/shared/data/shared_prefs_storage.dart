import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledger/shared/data/storage_interface.dart';

// =============================================================================
// SHARED PREFERENCES STORAGE - Concrete Implementation
// =============================================================================
//
// This is ONE possible implementation of LedgerStorage.
// Controllers depend on the interface, not this class.
//
// Benefits of interface abstraction:
// - Swap to Hive/Isar without touching business logic
// - Easy testing with InMemoryStorage
// - Future migration to encrypted storage

class SharedPreferencesStorage implements LedgerStorage {
  final SharedPreferences _prefs;
  final String _prefix;

  SharedPreferencesStorage._(this._prefs, this._prefix);

  factory SharedPreferencesStorage() {
    return _instance;
  }

  static late final SharedPreferencesStorage _instance;

  static Future<SharedPreferencesStorage> init() async {
    final prefs = await SharedPreferences.getInstance();
    _instance = SharedPreferencesStorage._(prefs, 'ledger_');
    return _instance;
  }

  // =========================================================================
  // Single Record Operations
  // =========================================================================

  @override
  Future<StorageRecord?> get(String key) async {
    try {
      final fullKey = '$_prefix$key';
      final json = _prefs.getString(fullKey);

      if (json == null) return null;

      final data = jsonDecode(json) as Map<String, dynamic>;
      return StorageRecord.fromJson(data);
    } catch (e) {
      throw LedgerStorageException('Failed to read $key: $e');
    }
  }

  @override
  Future<StorageRecord> save(String key, Map<String, dynamic> data) async {
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
      await _prefs.setString(fullKey, json);

      return record;
    } catch (e) {
      throw LedgerStorageException('Failed to save $key: $e');
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      final fullKey = '$_prefix$key';
      await _prefs.remove(fullKey);
    } catch (e) {
      throw LedgerStorageException('Failed to delete $key: $e');
    }
  }

  @override
  Future<bool> exists(String key) async {
    try {
      final fullKey = '$_prefix$key';
      return _prefs.containsKey(fullKey);
    } catch (e) {
      throw LedgerStorageException('Failed to check $key: $e');
    }
  }

  // =========================================================================
  // Batch Operations
  // =========================================================================

  @override
  Future<List<StorageRecord>> getAll({String? prefix}) async {
    try {
      final targetPrefix = prefix != null ? '$_prefix$prefix' : _prefix;
      final records = <StorageRecord>[];

      for (final key in _prefs.getKeys()) {
        if (key.startsWith(targetPrefix)) {
          final json = _prefs.getString(key);
          if (json != null) {
            try {
              final data = jsonDecode(json) as Map<String, dynamic>;
              records.add(StorageRecord.fromJson(data));
            } catch (_) {
              // Skip corrupted records silently
            }
          }
        }
      }

      return records;
    } catch (e) {
      throw LedgerStorageException('Failed to getAll: $e');
    }
  }

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
      }
    } catch (e) {
      throw LedgerStorageException('Failed to saveBatch: $e');
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
        await _prefs.remove(key);
      }
    } catch (e) {
      throw LedgerStorageException('Failed to deleteAll: $e');
    }
  }

  // =========================================================================
  // Transaction Support
  // =========================================================================

  @override
  Future<void> transaction(
    Future<void> Function(LedgerStorage storage) callback,
  ) async {
    // SharedPreferences doesn't support true transactions
    // We implement best-effort with rollback on failure
    try {
      // Backup current state
      final backup = await getAll();

      try {
        await callback(this);
      } catch (e) {
        // Attempt rollback
        try {
          await saveBatch(
            Map.fromEntries(
              backup.map((r) => MapEntry(r.key, r.data)),
            ),
          );
        } catch (rollbackError) {
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

  // =========================================================================
  // Health Check
  // =========================================================================

  @override
  Future<bool> validate() async {
    try {
      // Basic validation: check if we can read/write
      final testKey = '$_prefix health_check';
      await _prefs.setString(testKey, 'ok');
      final testValue = _prefs.getString(testKey);
      await _prefs.remove(testKey);

      return testValue == 'ok';
    } catch (_) {
      return false;
    }
  }
}

/// Exception type for storage errors
class LedgerStorageException implements Exception {
  final String message;
  LedgerStorageException(this.message);

  @override
  String toString() => 'LedgerStorageException: $message';
}
