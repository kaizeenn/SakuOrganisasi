import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart';

import '../database/database.dart';
import '../utils/app_constants.dart';

class MemberPaymentStatus {
  final int memberId;
  final String memberName;
  final bool hasPaid;
  final int? amount;

  MemberPaymentStatus({
    required this.memberId,
    required this.memberName,
    required this.hasPaid,
    this.amount,
  });
}

class MemberPaymentChecklistService {
  final AppDatabase _db;

  MemberPaymentChecklistService(this._db);

  /// Get all members with payment status for a specific period
  Future<List<MemberPaymentStatus>> getMemberPaymentStatus(int periodId) async {
    final period = await (_db.select(
      _db.cashPeriods,
    )..where((tbl) => tbl.id.equals(periodId))).getSingle();

    final allMembers = await (_db.select(
      _db.members,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

    final paidRows = await (_db.select(_db.cashLogs)..where((tbl) {
          final byId = tbl.periodId.equals(periodId);
          final byLegacyLabel =
              tbl.periodId.isNull() & tbl.periodLabel.equals(period.name);
          return byId | byLegacyLabel;
        }))
        .get();

    final paidMemberIds = paidRows.map((row) => row.memberId).toSet();

    final amountRows = await (_db.select(_db.cashLogs).join([
          innerJoin(
            _db.transactions,
            _db.cashLogs.transactionId.equalsExp(_db.transactions.id),
          ),
        ])
          ..where(((_db.cashLogs.periodId.equals(periodId)) |
              (_db.cashLogs.periodId.isNull() &
                  _db.cashLogs.periodLabel.equals(period.name)))))
        .get();

    final amountByMember = <int, int>{};
    for (final row in amountRows) {
      final log = row.readTable(_db.cashLogs);
      final tx = row.readTable(_db.transactions);
      amountByMember.update(
        log.memberId,
        (value) => value + tx.amount,
        ifAbsent: () => tx.amount,
      );
    }

    return allMembers.map((member) {
      final isPaid = paidMemberIds.contains(member.id);
      return MemberPaymentStatus(
        memberId: member.id,
        memberName: member.name,
        hasPaid: isPaid,
        amount: amountByMember[member.id],
      );
    }).toList();
  }

  /// Generate PDF checklist (single page)
  Future<Uint8List> generatePaymentChecklist(
    CashPeriod period,
    List<MemberPaymentStatus> members,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final orgName = prefs.getString('org_name') ?? AppConstants.defaultOrgName;
    final dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');
    final amountFormatter = NumberFormat.decimalPattern('id_ID');
    final now = DateTime.now();

    final pdf = pw.Document();

    final rows = members.isEmpty
        ? <List<String>>[
            ['-', 'Belum ada anggota', '-', '-', ''],
          ]
        : members.asMap().entries.map((entry) {
            final index = entry.key;
            final member = entry.value;
            return [
              '${index + 1}',
              member.memberName,
              member.hasPaid ? 'BAYAR' : 'BELUM',
              member.amount != null
                  ? 'Rp ${amountFormatter.format(member.amount)}'
                  : '-',
              '',
            ];
          }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) {
          return [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
              // Header
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      orgName,
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'DAFTAR PEMBAYARAN KAS ANGGOTA',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Periode: ${period.name}',
                      style: const pw.TextStyle(fontSize: 11),
                    ),
                    pw.Text(
                      '${dateFormatter.format(period.startDate)} - ${dateFormatter.format(period.endDate)}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Checklist Table
              pw.TableHelper.fromTextArray(
                headers: const [
                  'No',
                  'Nama Anggota',
                  'Status',
                  'Nominal',
                  'Tanda Tangan',
                ],
                data: rows,
                border: pw.TableBorder.all(color: PdfColors.black, width: 1),
                headerStyle: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FixedColumnWidth(28),
                  1: const pw.FlexColumnWidth(2.4),
                  2: const pw.FlexColumnWidth(1.1),
                  3: const pw.FlexColumnWidth(1.2),
                  4: const pw.FixedColumnWidth(72),
                },
              ),
              pw.SizedBox(height: 8),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total Bayar: ${members.where((m) => m.hasPaid).length}/${members.length}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 24),

                // Footer with SignOff
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildSignature('Diperiksa oleh:'),
                    _buildSignature('Disetujui oleh:'),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text(
                      'Tanggal Cetak: ${dateFormatter.format(now)} | Jam: ${DateFormat('HH:mm', 'id_ID').format(now)}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSignature(String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(height: 40),
        pw.Container(
          width: 150,
          height: 1,
          color: PdfColors.black,
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }
}
