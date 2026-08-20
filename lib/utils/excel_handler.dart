import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ExcelHandler {
  /// Exports expense data to an Excel (.xlsx) file in the system downloads folder.
  /// Filename format: SpendBookDDMMYY.xlsx
  static Future<String> exportExpenses(List<Map<String, dynamic>> expenses) async {
    final excel = Excel.createExcel();
    final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[sheetName];

    // Headers
    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Category'),
      TextCellValue('Amount'),
    ]);

    // Data rows
    for (final exp in expenses) {
      final String dateStr = exp['date'] as String;
      final String categoryStr = exp['category'] as String;
      final double amountVal = (exp['amount'] as num).toDouble();

      sheet.appendRow([
        TextCellValue(dateStr),
        TextCellValue(categoryStr),
        DoubleCellValue(amountVal),
      ]);
    }

    // Get Downloads directory.
    // getDownloadsDirectory() is supported on Windows desktop, macOS, Linux.
    Directory? downloadsDir = await getDownloadsDirectory();
    if (downloadsDir == null) {
      // Fallback path behavior on mobile platforms.
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
        }
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }
    }

    // Format current date: ddMMyy
    final now = DateTime.now();
    final dateSuffix = DateFormat('ddMMyy').format(now);
    final fileName = 'SpendBook$dateSuffix.xlsx';
    final filePath = p.join(downloadsDir.path, fileName);

    final fileBytes = excel.save();
    if (fileBytes != null) {
      final file = File(filePath);
      await file.create(recursive: true);
      await file.writeAsBytes(fileBytes);
    }

    return filePath;
  }

  /// Opens file picker and imports expense data from an Excel file.
  /// Performs validations on structure and date.
  /// Throws exceptions for validation errors to be handled by the UI.
  static Future<List<Map<String, dynamic>>> importExpenses() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null || result.files.single.path == null) {
      throw Exception('no_file_selected');
    }

    final path = result.files.single.path!;
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('file_not_found');
    }

    final bytes = await file.readAsBytes();
    return parseExcelBytes(bytes);
  }

  /// Parses and validates Excel bytes. Separated for easier unit testing.
  static List<Map<String, dynamic>> parseExcelBytes(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);

    if (excel.tables.isEmpty) {
      throw Exception('structure_mismatch');
    }

    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];

    if (sheet == null || sheet.maxRows == 0) {
      throw Exception('structure_mismatch');
    }

    // Check header row structure
    final headerRow = sheet.rows.first;
    if (headerRow.length < 3) {
      throw Exception('structure_mismatch');
    }

    final h1 = _getCellValueString(headerRow[0]);
    final h2 = _getCellValueString(headerRow[1]);
    final h3 = _getCellValueString(headerRow[2]);

    if (h1.toLowerCase() != 'date' ||
        h2.toLowerCase() != 'category' ||
        h3.toLowerCase() != 'amount') {
      throw Exception('structure_mismatch');
    }

    final List<Map<String, dynamic>> importedRows = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Iterate starting from row 1 (skipping header)
    for (int i = 1; i < sheet.maxRows; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty) continue;
      // Skip row if it is completely empty
      if (row.every((cell) => cell == null || cell.value == null)) continue;

      if (row.length < 3) {
        throw Exception('structure_mismatch');
      }

      final dateVal = _getCellValueString(row[0]).trim();
      final categoryVal = _getCellValueString(row[1]).trim();
      final amountVal = _getCellValueDouble(row[2]);

      if (dateVal.isEmpty || categoryVal.isEmpty || amountVal == null) {
        throw Exception('structure_mismatch');
      }

      // Parse date. Expecting YYYY-MM-DD
      DateTime? parsedDate;
      try {
        parsedDate = DateTime.parse(dateVal);
      } catch (_) {
        // Fallback
      }

      if (parsedDate == null) {
        throw Exception('structure_mismatch');
      }

      final dateOnly = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

      // Date must be strictly less than today (i.e. <= yesterday)
      if (!dateOnly.isBefore(today)) {
        throw Exception('invalid_dates');
      }

      importedRows.add({
        'date': DateFormat('yyyy-MM-dd').format(dateOnly),
        'category': categoryVal,
        'amount': amountVal,
      });
    }

    if (importedRows.isEmpty) {
      throw Exception('structure_mismatch');
    }

    return importedRows;
  }

  static String _getCellValueString(Data? cell) {
    if (cell == null || cell.value == null) return '';
    final val = cell.value;
    if (val is TextCellValue) {
      return val.value.text ?? '';
    }
    if (val is IntCellValue) {
      return val.value.toString();
    }
    if (val is DoubleCellValue) {
      return val.value.toString();
    }
    if (val is BoolCellValue) {
      return val.value.toString();
    }
    if (val is DateCellValue) {
      return '${val.year}-${val.month.toString().padLeft(2, '0')}-${val.day.toString().padLeft(2, '0')}';
    }
    return val.toString();
  }

  static double? _getCellValueDouble(Data? cell) {
    if (cell == null || cell.value == null) return null;
    final val = cell.value;
    if (val is DoubleCellValue) {
      return val.value;
    }
    if (val is IntCellValue) {
      return val.value.toDouble();
    }
    if (val is TextCellValue) {
      final txt = val.value.text;
      return txt != null ? double.tryParse(txt) : null;
    }
    return double.tryParse(val.toString());
  }
}
