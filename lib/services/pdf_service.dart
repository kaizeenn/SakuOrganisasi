import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/transaction_repository.dart';
import '../utils/app_constants.dart';

class PdfService {
  Future<Uint8List> generateTransactionReport(
    DateTime start,
    DateTime end,
    List<TransactionWithDetails> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final orgName = prefs.getString('org_name') ?? AppConstants.defaultOrgName;
    final currency = prefs.getString('currency') ?? 'IDR';

    final isIdr = currency == 'IDR';
    final currencyFormatter = NumberFormat.currency(
      locale: isIdr ? 'id_ID' : 'en_US',
      symbol: isIdr ? 'Rp ' : '\$',
      decimalDigits: 0,
    );
    final dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');

    final pdf = pw.Document();

    // Calculate Summary
    int totalIncome = 0;
    int totalExpense = 0;
    for (var item in data) {
      if (item.transaction.type == 'Income') {
        totalIncome += item.transaction.amount;
      } else if (item.transaction.type == 'Expense') {
        totalExpense += item.transaction.amount;
      }
    }
    final int netBalance = totalIncome - totalExpense;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Laporan Keuangan',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(orgName, style: const pw.TextStyle(fontSize: 14)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Periode: ${dateFormatter.format(start)} - ${dateFormatter.format(end)}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Summary Box
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text('Total Pemasukan'),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          currencyFormatter.format(totalIncome),
                          style: pw.TextStyle(
                            color: PdfColors.green,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text('Total Pengeluaran'),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          currencyFormatter.format(totalExpense),
                          style: pw.TextStyle(
                            color: PdfColors.red,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text('Saldo Bersih'),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          currencyFormatter.format(netBalance),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.TableHelper.fromTextArray(
              headers: [
                'Tanggal',
                'Tipe',
                'Kategori',
                'Deskripsi',
                'Nominal',
              ],
              data: data.map((item) {
                final typeLabel = item.transaction.type == 'Income'
                    ? 'Pemasukan'
                    : item.transaction.type == 'Expense'
                    ? 'Pengeluaran'
                    : 'Transfer';
                final description = item.transaction.type == 'Transfer' &&
                        item.destinationAccount != null
                    ? '${item.transaction.description.isEmpty ? 'Transfer saldo' : item.transaction.description} (${item.account.name} → ${item.destinationAccount!.name})'
                    : item.transaction.description;

                return [
                  dateFormatter.format(item.transaction.transactionDate),
                  typeLabel,
                  item.category.name,
                  description,
                  currencyFormatter.format(item.transaction.amount),
                ];
              }).toList(),
              border: null,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
                4: pw.Alignment.centerRight,
              },
            ),
          ];
        },
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Dicetak pada: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
