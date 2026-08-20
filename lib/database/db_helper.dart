import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DbHelper {
  static final DbHelper instance = DbHelper._init();
  static Database? _database;

  DbHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('spendbook.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        UNIQUE(date, category)
      )
    ''');
  }

  /// Capitalizes the first letter of each word and converts remaining letters to lower case.
  static String capitalizeCategory(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Inserts an expense. If category and date match, sums the amounts.
  Future<void> insertOrSumExpense(String category, double amount, String date) async {
    final normalizedCategory = capitalizeCategory(category);
    final db = await database;
    await db.transaction((txn) async {
      final List<Map<String, dynamic>> existing = await txn.query(
        'expenses',
        where: 'date = ? AND category = ?',
        whereArgs: [date, normalizedCategory],
      );

      if (existing.isNotEmpty) {
        final double currentAmount = existing.first['amount'] as double;
        final int id = existing.first['id'] as int;
        await txn.update(
          'expenses',
          {'amount': currentAmount + amount},
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        await txn.insert('expenses', {
          'date': date,
          'category': normalizedCategory,
          'amount': amount,
        });
      }
    });
  }

  /// Retrieves expenses. Optional date filters in 'YYYY-MM-DD' format.
  Future<List<Map<String, dynamic>>> getExpenses({String? startDate, String? endDate}) async {
    final db = await database;
    if (startDate != null && endDate != null) {
      return await db.query(
        'expenses',
        where: 'date >= ? AND date <= ?',
        whereArgs: [startDate, endDate],
        orderBy: 'date ASC, category ASC',
      );
    } else {
      return await db.query(
        'expenses',
        orderBy: 'date ASC, category ASC',
      );
    }
  }

  /// Gets the count of unique dates with entries.
  Future<int> getUniqueDatesCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(DISTINCT date) as count FROM expenses');
    if (result.isNotEmpty) {
      return result.first['count'] as int? ?? 0;
    }
    return 0;
  }

  /// Gets all distinct categories currently stored in expenses.
  Future<List<String>> getDistinctCategories() async {
    final db = await database;
    final result = await db.rawQuery('SELECT DISTINCT category FROM expenses ORDER BY category ASC');
    return result
        .map((row) => row['category'] as String?)
        .whereType<String>()
        .toList();
  }

  /// Bulk imports records. If a date matches, its existing database records are replaced.
  Future<void> importExpenses(List<Map<String, dynamic>> rows) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Group and aggregate imported rows by date and category to prevent internal duplicates
      // date -> category -> totalAmount
      final Map<String, Map<String, double>> aggregated = {};

      for (final row in rows) {
        final String date = row['date'] as String;
        final String rawCategory = row['category'] as String;
        final String category = capitalizeCategory(rawCategory);
        final double amount = (row['amount'] as num).toDouble();

        aggregated.putIfAbsent(date, () => {});
        aggregated[date]![category] = (aggregated[date]![category] ?? 0.0) + amount;
      }

      // 2. Delete all existing records for the dates present in the import
      for (final date in aggregated.keys) {
        await txn.delete(
          'expenses',
          where: 'date = ?',
          whereArgs: [date],
        );
      }

      // 3. Insert the newly aggregated records
      for (final date in aggregated.keys) {
        final categories = aggregated[date]!;
        for (final category in categories.keys) {
          final double amount = categories[category]!;
          await txn.insert('expenses', {
            'date': date,
            'category': category,
            'amount': amount,
          });
        }
      }
    });
  }

  /// Clears the entire database (helpful for testing/resetting)
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('expenses');
  }
}
