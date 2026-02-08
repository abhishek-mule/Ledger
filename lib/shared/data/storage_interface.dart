// =============================================================================
// LEDGER STORAGE INTERFACE - Storage-Agnostic Persistence Contract
// =============================================================================
//
// This interface defines the persistence contract. Implementations can be:
// - SharedPreferencesStorage (current)
// - HiveStorage
// - IsarStorage
// - FileStorage
//
// All business logic depends on this interface, never on concrete storage.

import 'dart:async';

/// Immutable data record for storage
class StorageRecord {
  final String key;
  final Map<String, dynamic> data;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StorageRecord({
    required this.key,
    required this.data,
    this.createdAt,
    this.updatedAt,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'data': data,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory StorageRecord.fromJson(Map<String, dynamic> json) {
    return StorageRecord(
      key: json['key'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

/// Abstract storage interface - storage-agnostic contract
abstract class LedgerStorage {
  // Single record operations
  Future<StorageRecord?> get(String key);
  Future<StorageRecord> save(String key, Map<String, dynamic> data);
  Future<void> delete(String key);
  Future<bool> exists(String key);

  // Batch operations
  Future<List<StorageRecord>> getAll({String? prefix});
  Future<void> saveBatch(Map<String, Map<String, dynamic>> records);
  Future<void> deleteAll({String? prefix});

  // Transaction support
  Future<void> transaction(
    Future<void> Function(LedgerStorage storage) callback,
  );

  // Health check
  Future<bool> validate();
}
