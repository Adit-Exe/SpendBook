import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:spend_book/database/db_helper.dart';

void main() {
  // Initialize sqflite ffi for tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Database Helper Tests', () {
    late DbHelper dbHelper;

    setUp(() async {
      dbHelper = DbHelper.instance;
      await dbHelper.clearAll();
    });

    tearDown(() async {
      await dbHelper.clearAll();
    });

    test('Saving payments on same day and category should sum the amount', () async {
      const category = 'Travel';
      const date = '2026-06-25';

      // Insert first payment
      await dbHelper.insertOrSumExpense(category, 100.0, date);
      
      // Insert second payment on same day, same category
      await dbHelper.insertOrSumExpense(category, 150.0, date);

      final expenses = await dbHelper.getExpenses();
      expect(expenses.length, equals(1));
      expect(expenses.first['category'], equals(category));
      expect(expenses.first['date'], equals(date));
      expect(expenses.first['amount'], equals(250.0));
    });

    test('Saving payments on different days or categories should create separate rows', () async {
      // Different categories, same day
      await dbHelper.insertOrSumExpense('Travel', 100.0, '2026-06-25');
      await dbHelper.insertOrSumExpense('Food', 50.0, '2026-06-25');

      // Same category, different day
      await dbHelper.insertOrSumExpense('Travel', 200.0, '2026-06-26');

      final expenses = await dbHelper.getExpenses();
      expect(expenses.length, equals(3));
    });

    test('Importing data should replace existing data on the same date', () async {
      // Insert existing data
      await dbHelper.insertOrSumExpense('Travel', 100.0, '2026-06-25');
      await dbHelper.insertOrSumExpense('Food', 50.0, '2026-06-25');
      await dbHelper.insertOrSumExpense('Invest', 500.0, '2026-06-26');

      // Import new rows for 2026-06-25 (replaces existing 2026-06-25)
      final importRows = [
        {'date': '2026-06-25', 'category': 'Travel', 'amount': 150.0},
        {'date': '2026-06-25', 'category': 'Shopping', 'amount': 75.0},
      ];

      await dbHelper.importExpenses(importRows);

      final expenses = await dbHelper.getExpenses();
      // Should have 3 records:
      // - 2026-06-25 Travel (150.0) -> replaced
      // - 2026-06-25 Shopping (75.0) -> added
      // - 2026-06-26 Invest (500.0) -> unaffected (since date is 2026-06-26)
      // Note: Food (50.0) on 2026-06-25 is deleted/replaced because we replaced the entire date's data.
      expect(expenses.length, equals(3));

      final travel25 = expenses.firstWhere((e) => e['date'] == '2026-06-25' && e['category'] == 'Travel');
      final shopping25 = expenses.firstWhere((e) => e['date'] == '2026-06-25' && e['category'] == 'Shopping');
      final invest26 = expenses.firstWhere((e) => e['date'] == '2026-06-26' && e['category'] == 'Invest');

      expect(travel25['amount'], equals(150.0));
      expect(shopping25['amount'], equals(75.0));
      expect(invest26['amount'], equals(500.0));

      // Food should be deleted/cleared for 2026-06-25
      final food25Matches = expenses.where((e) => e['date'] == '2026-06-25' && e['category'] == 'Food');
      expect(food25Matches.isEmpty, isTrue);
    });

    group('Date threshold checks', () {
      test('Unique dates count calculation', () async {
        expect(await dbHelper.getUniqueDatesCount(), equals(0));

        await dbHelper.insertOrSumExpense('Food', 10.0, '2026-06-20');
        await dbHelper.insertOrSumExpense('Travel', 20.0, '2026-06-20'); // same day
        expect(await dbHelper.getUniqueDatesCount(), equals(1));

        await dbHelper.insertOrSumExpense('Food', 10.0, '2026-06-21');
        await dbHelper.insertOrSumExpense('Food', 10.0, '2026-06-22');
        expect(await dbHelper.getUniqueDatesCount(), equals(3));
      });
    });
  });
}
