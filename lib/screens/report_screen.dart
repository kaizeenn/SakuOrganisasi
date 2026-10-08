import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../providers/dashboard_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../services/pdf_service.dart';
import '../services/excel_service.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final PdfService _pdfService = PdfService();
  final ExcelService _excelService = ExcelService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: p.brandSoft,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        Icons.date_range_rounded,
                        color: p.brand,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Periode Laporan', style: context.texts.titleMedium),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _dateButton(
                        label: 'Dari',
                        date: _startDate,
                        onTap: () => _pickDate(true),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: p.textMuted,
                        size: 18,
                      ),
                    ),
                    Expanded(
                      child: _dateButton(
                        label: 'Sampai',
                        date: _endDate,
                        onTap: () => _pickDate(false),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _ExportTile(
            icon: Icons.picture_as_pdf_rounded,
            color: p.expense,
            title: 'PDF Siap Cetak',
            subtitle: 'Format formal untuk laporan fisik',
            onTap: _isLoading ? null : _exportPdf,
          ),
          const SizedBox(height: 12),
          _ExportTile(
            icon: Icons.table_chart_rounded,
            color: p.income,
            title: 'Excel (.xlsx)',
            subtitle: 'Data mentah untuk analisis lanjutan',
            onTap: _isLoading ? null : _exportExcel,
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            FilledButton.icon(
              onPressed: _showExportOptions,
              icon: const Icon(Icons.download_rounded, size: 18),
              label: const Text('Export Laporan'),
            ),
        ],
      ),
    );
  }

  Widget _dateButton({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    final p = context.palette;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      radius: AppRadius.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.texts.labelSmall?.copyWith(color: p.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('dd MMM yyyy', 'id_ID').format(date),
            style: context.texts.titleSmall,
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final p = context.palette;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                _ExportTile(
                  icon: Icons.picture_as_pdf_rounded,
                  color: p.expense,
                  title: 'PDF (Siap Cetak)',
                  subtitle: 'Formal, cocok untuk laporan fisik.',
                  onTap: () {
                    Navigator.pop(context);
                    _exportPdf();
                  },
                ),
                const SizedBox(height: 12),
                _ExportTile(
                  icon: Icons.table_chart_rounded,
                  color: p.income,
                  title: 'Excel (.xlsx)',
                  subtitle: 'Raw data untuk analisis lanjutan.',
                  onTap: () {
                    Navigator.pop(context);
                    _exportExcel();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportPdf() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final data = await repo.getTransactionsByDateRange(_startDate, _endDate);
      if (data.isEmpty) {
        if (mounted) _snack('Data kosong pada periode ini.');
        return;
      }
      final pdfBytes = await _pdfService.generateTransactionReport(
        _startDate,
        _endDate,
        data,
      );
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Laporan_${DateFormat('yyyyMMdd').format(_startDate)}.pdf',
      );
    } catch (e) {
      if (mounted) _snack('Error PDF: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportExcel() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final data = await repo.getTransactionsByDateRange(_startDate, _endDate);
      if (data.isEmpty) {
        if (mounted) _snack('Data kosong pada periode ini.');
        return;
      }
      await _excelService.generateAndExportExcel(data, _startDate, _endDate);
      if (mounted) _snack('Export Excel selesai (cek share menu).');
    } catch (e) {
      if (mounted) _snack('Error Excel: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ExportTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ExportTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.texts.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: context.texts.bodySmall?.copyWith(color: p.textMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.textMuted, size: 20),
        ],
      ),
    );
  }
}