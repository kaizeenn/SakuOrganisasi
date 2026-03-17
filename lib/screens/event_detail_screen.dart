import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../database/database.dart';
import 'package:drift/drift.dart' as drift;
import '../providers/dashboard_providers.dart';
import '../repositories/transaction_repository.dart';
import '../widgets/transaction_item_card.dart';
import 'package:flutter/services.dart';
import '../utils/currency_format.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(transactionRepositoryProvider);
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<Event>(
      stream: repo.watchEventById(widget.event.id),
      initialData: widget.event,
      builder: (context, eventSnapshot) {
        final liveEvent = eventSnapshot.data;

        if (liveEvent == null) {
          return const Scaffold(
            body: Center(
              child: Text("Event tidak ditemukan (mungkin dihapus)"),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(liveEvent.name),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showEditDialog(context, ref, liveEvent),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
          body: StreamBuilder<List<TransactionWithDetails>>(
            stream: repo.watchTransactionsByEvent(liveEvent.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                // If we have no data at all, show spinner.
                // But usually we want instant load if cached.
                // Since this is secondary stream, simple loading is okay.
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              final transactions = snapshot.data ?? [];

              // Calculate Metrics
              int totalExpense = 0;
              for (var item in transactions) {
                if (item.transaction.type == 'Expense') {
                  totalExpense += item.transaction.amount;
                }
              }

              final budget = liveEvent.budgetLimit;
              final remaining = budget - totalExpense;
              final progress = budget > 0
                  ? (totalExpense / budget).clamp(0.0, 1.0)
                  : 0.0;
              final isOverBudget = remaining < 0;

              return Column(
                children: [
                  // Header Metrics
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).appBarTheme.backgroundColor,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                      boxShadow: isDarkMode
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: liveEvent.status == 'Active'
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                liveEvent.status,
                                style: TextStyle(
                                  color: liveEvent.status == 'Active'
                                      ? Colors.green
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Anggaran: ${currencyFormatter.format(budget)}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.date_range,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${DateFormat('dd MMM').format(liveEvent.startDate)} '
                              '${liveEvent.endDate != null ? "- ${DateFormat('dd MMM yyyy').format(liveEvent.endDate!)}" : "- Sekarang"}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Sisa Anggaran',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currencyFormatter.format(remaining),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: isOverBudget
                                ? Colors.red
                                : (isDarkMode ? Colors.white : Colors.black87),
                          ),
                        ),
                        if (isOverBudget)
                          const Text(
                            '(Over Budget)',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),

                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 12,
                            backgroundColor: isDarkMode
                                ? (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.black12
                                      : Colors.white10)
                                : Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress > 0.9 ? Colors.red : Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Terpakai: ${(progress * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ).animate().fade().slideY(begin: -0.2, end: 0, duration: 400.ms),
                  ),

                  // Transaction List
                  Expanded(
                    child: transactions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.event_note,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Belum ada transaksi untuk event ini',
                                ),
                              ],
                            ).animate().fade(),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: transactions.length,
                            itemBuilder: (context, index) {
                              final item = transactions[index];
                              return TransactionItemCard(
                                item: item,
                              ).animate().fade().slideX(
                                begin: 0.1,
                                end: 0,
                                delay: (index * 20).ms,
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Event?'),
        content: const Text(
          'Transaksi terkait TIDAK akan dihapus, tetapi akan dilepas dari event ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.deleteEvent(widget.event.id);
      if (context.mounted) {
        Navigator.pop(context); // Back to List
      }
    }
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Event currentEvent,
  ) {
    showDialog(
      context: context,
      builder: (context) => _EditEventDialog(event: currentEvent),
    );
  }
}

class _EditEventDialog extends ConsumerStatefulWidget {
  final Event event;
  const _EditEventDialog({required this.event});

  @override
  ConsumerState<_EditEventDialog> createState() => _EditEventDialogState();
}

class _EditEventDialogState extends ConsumerState<_EditEventDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _budgetController;
  late String _status;
  late DateTime _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.event.name);
    _budgetController = TextEditingController(
      text: widget.event.budgetLimit.toString(),
    );
    _status = widget.event.status;
    _startDate = widget.event.startDate;
    _endDate = widget.event.endDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Event'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nama Event'),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _budgetController,
                decoration: const InputDecoration(labelText: 'Anggaran (Rp)'),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  RupiahInputFormatter(),
                ],
                validator: (val) =>
                    val == null || val.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                // value: _status, // Deprecated in favor of initialValue for form fields
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'Active', child: Text('Aktif')),
                  DropdownMenuItem(value: 'Completed', child: Text('Selesai')),
                  DropdownMenuItem(
                    value: 'Cancelled',
                    child: Text('Dibatalkan'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _status = val);
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Tanggal Mulai'),
                  child: Text(DateFormat('dd MMM yyyy').format(_startDate)),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate ?? _startDate,
                    firstDate: _startDate,
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _endDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Selesai (Opsional)',
                  ),
                  child: Text(
                    _endDate != null
                        ? DateFormat('dd MMM yyyy').format(_endDate!)
                        : '-',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final repo = ref.read(transactionRepositoryProvider);

      // 1. Sanitize Budget Input (Remove 'Rp' and dots)
      final cleanBudget = _budgetController.text.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );

      // 2. Create Companion (Explicitly passing ID from the original event)
      final updated = widget.event
          .toCompanion(true)
          .copyWith(
            name: drift.Value(_nameController.text),
            budgetLimit: drift.Value(int.parse(cleanBudget)),
            status: drift.Value(_status),
            startDate: drift.Value(_startDate),
            endDate: drift.Value(_endDate), // Nullable is fine here
          );

      // 3. Update via Repository
      await repo.updateEvent(updated);

      if (mounted) {
        Navigator.pop(context); // Close Dialog on Success
      }
    }
  }
}
