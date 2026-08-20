import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:spend_book/utils/excel_handler.dart';

void main() {
  group('Excel Handler Validation Tests', () {
    test('Valid excel file should parse correctly', () {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];
      
      // Write headers
      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Category'),
        TextCellValue('Amount'),
      ]);

      // Write valid data (dates in the past)
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      sheet.appendRow([
        TextCellValue(yesterdayStr),
        TextCellValue('Food'),
        DoubleCellValue(50.0),
      ]);

      final bytes = excel.save()!;
      final parsed = ExcelHandler.parseExcelBytes(bytes);

      expect(parsed.length, equals(1));
      expect(parsed.first['date'], equals(yesterdayStr));
      expect(parsed.first['category'], equals('Food'));
      expect(parsed.first['amount'], equals(50.0));
    });

    test('Excel file with mismatched structure should throw structure_mismatch error', () {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Mismatched headers
      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Category'),
        TextCellValue('Total'), // Mismatch (should be 'Amount')
      ]);

      final bytes = excel.save()!;
      expect(
        () => ExcelHandler.parseExcelBytes(bytes),
        throwsA(predicate((e) => e.toString().contains('structure_mismatch'))),
      );
    });

    test('Excel file with today\'s date should throw invalid_dates error', () {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Category'),
        TextCellValue('Amount'),
      ]);

      // Today's date (should not be allowed, only past dates allowed)
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      sheet.appendRow([
        TextCellValue(todayStr),
        TextCellValue('Food'),
        DoubleCellValue(50.0),
      ]);

      final bytes = excel.save()!;
      expect(
        () => ExcelHandler.parseExcelBytes(bytes),
        throwsA(predicate((e) => e.toString().contains('invalid_dates'))),
      );
    });

    test('Excel file with future dates should throw invalid_dates error', () {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      sheet.appendRow([
        TextCellValue('Date'),
        TextCellValue('Category'),
        TextCellValue('Amount'),
      ]);

      // Future date (should not be allowed)
      final futureStr = DateFormat('yyyy-MM-dd').format(
        DateTime.now().add(const Duration(days: 2)),
      );
      sheet.appendRow([
        TextCellValue(futureStr),
        TextCellValue('Travel'),
        DoubleCellValue(150.0),
      ]);

      final bytes = excel.save()!;
      expect(
        () => ExcelHandler.parseExcelBytes(bytes),
        throwsA(predicate((e) => e.toString().contains('invalid_dates'))),
      );
    });
  });
}
