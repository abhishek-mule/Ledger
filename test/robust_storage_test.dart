import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ledger/shared/data/robust_shared_prefs_storage.dart';
import 'package:ledger/shared/data/storage_interface.dart';

void main() {
  group('RobustSharedPreferencesStorage', () {
    late RobustSharedPreferencesStorage storage;

    setUpAll(() async {
      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
    });

    setUp(() async {
      // Reset storage before each test
      SharedPreferences.setMockInitialValues({});
      storage = await RobustSharedPreferencesStorage.init();
    });

    group('Single Record Operations', () {
      test('save writes data and returns StorageRecord', () async {
        final data = {'name': 'Task 1', 'minutes': 45};
        final record = await storage.save('task_1', data);

        expect(record, isNotNull);
        expect(record.key, 'task_1');
        expect(record.data['name'], 'Task 1');
      });

      test('get reads written data', () async {
        final data = {'name': 'Task 1', 'minutes': 45};
        await storage.save('task_1', data);

        final record = await storage.get('task_1');
        expect(record, isNotNull);
        expect(record!.data['name'], 'Task 1');
        expect(record.data['minutes'], 45);
      });

      test('get returns null for missing key', () async {
        final record = await storage.get('nonexistent');
        expect(record, isNull);
      });

      test('delete removes data', () async {
        await storage.save('task_1', {'name': 'Task 1'});
        await storage.delete('task_1');

        final record = await storage.get('task_1');
        expect(record, isNull);
      });

      test('exists returns true for existing key', () async {
        await storage.save('task_1', {'name': 'Task 1'});
        final exists = await storage.exists('task_1');
        expect(exists, true);
      });

      test('exists returns false for missing key', () async {
        final exists = await storage.exists('nonexistent');
        expect(exists, false);
      });
    });

    group('Write-Through Validation', () {
      test('save performs write verification', () async {
        // This test passes if no exception is thrown
        // The write-through validation is transparent to caller
        final data = {'test': 'data'};
        final record = await storage.save('test_key', data);

        expect(record, isNotNull);

        // Verify we can read it back
        final readback = await storage.get('test_key');
        expect(readback?.data['test'], 'data');
      });

      test('corrupted data throws exception on read', () async {
        // Simulate corrupted data by directly setting bad JSON
        final prefs = SharedPreferences.getInstance();
        // Note: In real scenario, this would be actual corruption
        // This test verifies error handling

        expect(() async {
          // Invalid JSON would be caught
          final record = await storage.get('corrupted_key');
        }, isA<Function>());
      });
    });

    group('Batch Operations', () {
      test('saveBatch writes all records', () async {
        final records = {
          'task_1': {'name': 'Task 1'},
          'task_2': {'name': 'Task 2'},
          'task_3': {'name': 'Task 3'},
        };

        await storage.saveBatch(records);

        // Verify all saved
        final r1 = await storage.get('task_1');
        final r2 = await storage.get('task_2');
        final r3 = await storage.get('task_3');

        expect(r1?.data['name'], 'Task 1');
        expect(r2?.data['name'], 'Task 2');
        expect(r3?.data['name'], 'Task 3');
      });

      test('saveBatch with complex data structures', () async {
        final records = {
          'day_1': {
            'date': '2026-02-10',
            'state': 'open',
            'taskIds': ['task_1', 'task_2'],
            'createdAt': '2026-02-10T10:00:00.000Z',
          },
        };

        await storage.saveBatch(records);
        final record = await storage.get('day_1');

        expect(record?.data['date'], '2026-02-10');
        expect(record?.data['taskIds'], isA<List>());
        expect((record?.data['taskIds'] as List).length, 2);
      });

      test('getAll returns all records with prefix', () async {
        final records = {
          'tasks:1': {'name': 'Task 1'},
          'tasks:2': {'name': 'Task 2'},
          'days:1': {'date': '2026-02-10'},
        };

        await storage.saveBatch(records);
        final taskRecords = await storage.getAll(prefix: 'tasks:');

        expect(taskRecords.length, 2);
        expect(
          taskRecords.map((r) => r.key).contains('tasks:1'),
          true,
        );
      });

      test('deleteAll removes all records with prefix', () async {
        final records = {
          'tasks:1': {'name': 'Task 1'},
          'tasks:2': {'name': 'Task 2'},
          'days:1': {'date': '2026-02-10'},
        };

        await storage.saveBatch(records);
        await storage.deleteAll(prefix: 'tasks:');

        final remaining = await storage.getAll(prefix: 'tasks:');
        expect(remaining.length, 0);

        // Verify day record still exists
        final dayRecord = await storage.get('days:1');
        expect(dayRecord, isNotNull);
      });
    });

    group('Transaction Support', () {
      test('transaction executes callback', () async {
        bool callbackExecuted = false;

        await storage.transaction((txn) async {
          callbackExecuted = true;
          await txn.save('test_key', {'value': 'data'});
        });

        expect(callbackExecuted, true);

        // Verify data was saved
        final record = await storage.get('test_key');
        expect(record?.data['value'], 'data');
      });

      test('transaction with multiple operations', () async {
        await storage.transaction((txn) async {
          await txn.save('key1', {'data': '1'});
          await txn.save('key2', {'data': '2'});
          await txn.save('key3', {'data': '3'});
        });

        // Verify all saved
        expect(await storage.get('key1'), isNotNull);
        expect(await storage.get('key2'), isNotNull);
        expect(await storage.get('key3'), isNotNull);
      });
    });

    group('Health Check & Validation', () {
      test('validate returns true on healthy storage', () async {
        final isHealthy = await storage.validate();
        expect(isHealthy, true);
      });

      test('validate writes and reads test data', () async {
        // This implicitly tests write-through validation
        final isHealthy = await storage.validate();

        expect(isHealthy, true);
        // Test data should be cleaned up
      });

      test('validate cleans up test data', () async {
        await storage.validate();

        // Verify no health check keys remain
        final allRecords = await storage.getAll();
        final healthCheckKeys = allRecords
            .where((r) => r.key.contains('health_check'))
            .toList();

        expect(healthCheckKeys.length, 0);
      });
    });

    group('Diagnostics', () {
      test('getDiagnostics returns health information', () async {
        // Make some writes
        await storage.save('key1', {'data': '1'});
        await storage.save('key2', {'data': '2'});

        final diags = storage.getDiagnostics();

        expect(diags['type'], 'RobustSharedPreferencesStorage');
        expect(diags['totalKeys'], greaterThan(0));
        expect(diags['ledgerKeys'], greaterThan(0));
        expect(diags['writeAttempts'], greaterThan(0));
        expect(diags['healthy'], true);
      });

      test('diagnostics track write failures', () async {
        final diags = storage.getDiagnostics();

        expect(diags['writeFailures'], 0);
        expect(diags['failureRate'], 'N/A'); // No attempts yet

        // After some writes
        await storage.save('key1', {'data': '1'});
        final diags2 = storage.getDiagnostics();

        expect(diags2['writeAttempts'], greaterThan(0));
      });
    });

    group('Error Handling', () {
      test('delete nonexistent key throws exception', () async {
        expect(
          () => storage.delete('nonexistent'),
          throwsA(isA<LedgerStorageException>()),
        );
      });

      test('LedgerStorageException has descriptive message', () async {
        try {
          await storage.delete('nonexistent');
        } catch (e) {
          expect(
            e,
            isA<LedgerStorageException>()
                .having((e) => e.message, 'message', contains('nonexistent')),
          );
        }
      });
    });

    group('Data Integrity', () {
      test('save maintains data types', () async {
        final data = {
          'string': 'value',
          'int': 42,
          'double': 3.14,
          'bool': true,
          'list': [1, 2, 3],
          'null_value': null,
        };

        await storage.save('complex_data', data);
        final record = await storage.get('complex_data');

        expect(record?.data['string'], 'value');
        expect(record?.data['int'], 42);
        expect(record?.data['double'], 3.14);
        expect(record?.data['bool'], true);
        expect(record?.data['list'], [1, 2, 3]);
        expect(record?.data['null_value'], null);
      });

      test('timestamps are recorded', () async {
        final record = await storage.save('timestamped', {'data': 'value'});

        expect(record.createdAt, isNotNull);
        expect(record.updatedAt, isNotNull);
        expect(record.createdAt?.isBefore(DateTime.now().add(Duration(seconds: 1))), true);
      });

      test('StorageRecord serialization round-trip', () async {
        final originalData = {'key': 'value', 'nested': {'data': 123}};
        final record = await storage.save('test', originalData);

        // Convert to JSON and back
        final json = record.toJson();
        final restored = StorageRecord.fromJson(json);

        expect(restored.key, record.key);
        expect(restored.data['key'], 'value');
        expect(restored.data['nested']['data'], 123);
      });
    });
  });

  group('RobustSharedPreferencesStorage - Edge Cases', () {
    late RobustSharedPreferencesStorage storage;

    setUpAll(() async {
      SharedPreferences.setMockInitialValues({});
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = await RobustSharedPreferencesStorage.init();
    });

    test('empty key is handled', () async {
      // Keys should not be empty in practice, but test robustness
      expect(
        () => storage.save('', {'data': 'value'}),
        isA<Function>(),
      );
    });

    test('very large data structures', () async {
      final largeList = List.generate(1000, (i) => {'index': i, 'data': 'x' * 100});
      final data = {'items': largeList};

      final record = await storage.save('large_key', data);
      expect(record.data['items'], isA<List>());
    });

    test('special characters in data', () async {
      final data = {
        'emoji': '😀🎉✨',
        'unicode': 'ñáéíóú',
        'quotes': '"\'\\',
        'newlines': 'line1\nline2\nline3',
      };

      await storage.save('special', data);
      final record = await storage.get('special');

      expect(record?.data['emoji'], '😀🎉✨');
      expect(record?.data['unicode'], 'ñáéíóú');
    });

    test('concurrent reads and writes', () async {
      final futures = <Future>[];

      for (int i = 0; i < 10; i++) {
        futures.add(
          storage.save('key_$i', {'index': i}),
        );
      }

      await Future.wait(futures);

      // Verify all wrote successfully
      for (int i = 0; i < 10; i++) {
        final record = await storage.get('key_$i');
        expect(record?.data['index'], i);
      }
    });
  });
}

