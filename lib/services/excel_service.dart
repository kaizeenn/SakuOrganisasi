import 'dart:io';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../repositories/transaction_repository.dart'; // Import this
// import '../database/database.dart'; // Removing if unused, or keeping if needed for other types

class ExcelService {
  Future<void> generateAndExportExcel(
    List<TransactionWithDetails> data,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final excel = Excel.createExcel();
      // Remove default sheet if possible, or use it. usually 'Sheet1' exists.
      final sheetName = 'Laporan Keuangan';
      final Sheet sheet = excel[sheetName];

      // Default sheet might need to be removed or renamed, but adding new sheet is safer.
      // excel.delete('Sheet1'); // Optional cleanup

      // 1. Header Row
      // CellStyle for Header
      final headerStyle = CellStyle(
        bold: true,
        horizontalAlign: HorizontalAlign.Center,
        backgroundColorHex: ExcelColor.blueGrey200,
      );

      final headers = [
        'Tanggal',
        'Tipe',
        'Kategori',
        'Deskripsi',
        'Masuk (IDR)',
        'Keluar (IDR)',
        'Transfer (IDR)',
        'Akun',
      ];

      // Add Header
      for (var i = 0; i < headers.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // 2. Data Rows
      final dateFormat = DateFormat('dd/MM/yyyy');

      for (var i = 0; i < data.length; i++) {
        final item = data[i];
        final txn = item.transaction;
        final rowIndex = i + 1;

        // Date
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          dateFormat.format(txn.transactionDate),
        );

        // Type
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          txn.type == 'Income'
              ? 'Pemasukan'
              : txn.type == 'Expense'
              ? 'Pengeluaran'
              : 'Transfer',
        );

        // Category
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          item.category.name,
        );

        // Description
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          txn.type == 'Transfer' && item.destinationAccount != null
              ? '${txn.description.isEmpty ? 'Transfer saldo' : txn.description} (${item.account.name} -> ${item.destinationAccount!.name})'
              : txn.description,
        );

        // Amount Columns
        if (txn.type == 'Income') {
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
              )
              .value = IntCellValue(
            txn.amount,
          ); // Raw int for calculation
        } else if (txn.type == 'Expense') {
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
              )
              .value = IntCellValue(
            txn.amount,
          );
        } else {
          sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex),
              )
              .value = IntCellValue(
            txn.amount,
          );
        }

        // Account
        sheet
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex),
            )
            .value = TextCellValue(
          txn.type == 'Transfer' && item.destinationAccount != null
              ? '${item.account.name} -> ${item.destinationAccount!.name}'
              : item.account.name,
        );
      }

      // Auto-fit columns is not fully supported in excel package yet, but data is there.

      // 3. Save File
      final directory = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'Laporan_Keuangan_$dateStr.xlsx';
      final file = File('${directory.path}/$fileName');

      // Encode
      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception('Gagal generate file Excel.');

      await file.writeAsBytes(fileBytes);

      // 4. Share
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Laporan Keuangan ${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}',
      );
    } catch (e) {
      throw Exception('Gagal export Excel: $e');
    }
  }
}
