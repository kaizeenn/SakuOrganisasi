import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_providers.dart';
import '../database/database.dart'; // For EventsCompanion
import '../screens/event_detail_screen.dart';
import '../repositories/transaction_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import '../utils/currency_format.dart';

class EventListScreen extends ConsumerWidget {
  const EventListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsWithSpendingProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Kegiatan & Proker',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Berjalan'),
              Tab(text: 'Riwayat'),
            ],
          ),
        ),
        body: eventsAsync.when(
          data: (events) {
            // Filter Events
            final activeEvents = events
                .where((e) => e.event.status == 'Active')
                .toList();
            final historyEvents = events
                .where((e) => e.event.status != 'Active')
                .toList();

            return TabBarView(
              children: [
                _EventList(
                  events: activeEvents,
                  isEmptyMessage: 'Tidak ada kegiatan aktif.',
                  isHistory: false,
                ),
                _EventList(
                  events: historyEvents,
                  isEmptyMessage: 'Belum ada riwayat kegiatan.',
                  isHistory: true,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(child: Text('Error: $err')),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddEventDialog(context, ref),
          label: const Text('Buat Proker'),
          icon: const Icon(Icons.add),
          backgroundColor: Colors.blue,
        ),
      ),
    );
  }

  void _showAddEventDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // Initial Values
    DateTime startDate = DateTime.now();
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Tambah Kegiatan/Proker'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nama Kegiatan',
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: budgetController,
                      decoration: const InputDecoration(
                        labelText: 'Anggaran (Budget)',
                        hintText: 'Rp 0',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        RupiahInputFormatter(),
                      ],
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Wajib diisi';
                        // if (int.tryParse(val) == null) return 'Harus angka'; // No longer valid with "Rp " prefix
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Date Pickers inside a Row
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() => startDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Mulai',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                              ),
                              child: Text(
                                DateFormat('dd MMM yyyy').format(startDate),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: endDate ?? startDate,
                                firstDate: startDate,
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() => endDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Selesai (Opsional)',
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                              ),
                              child: Text(
                                endDate != null
                                    ? DateFormat('dd MMM yyyy').format(endDate!)
                                    : '-',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final repo = ref.read(transactionRepositoryProvider);
                      // Import alias for drift if needed or just import it at top of file
                      // Assuming Value is available via database.dart export or need to import drift.
                      // Since database.dart usually exports drift, we check imports.
                      // If not, we might need `import 'package:drift/drift.dart' as drift;`

                      final cleanBudget = budgetController.text.replaceAll(
                        RegExp(r'[^0-9]'),
                        '',
                      );

                      await repo.createEvent(
                        EventsCompanion.insert(
                          name: nameController.text,
                          budgetLimit: int.parse(cleanBudget),
                          status: 'Active',
                          startDate: startDate,
                          endDate: endDate != null
                              ? Value(endDate)
                              : const Value.absent(),
                        ),
                      );
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _EventList extends StatelessWidget {
  final List<EventWithSpending> events;
  final String isEmptyMessage;
  final bool isHistory;

  const _EventList({
    required this.events,
    required this.isEmptyMessage,
    required this.isHistory,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isHistory ? Icons.history : Icons.event_available,
              size: 64,
              color: Colors.grey.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(isEmptyMessage, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final item = events[index];
        final event = item.event;
        final spent = item.spentAmount;
        final budget = event.budgetLimit;
        final progress = budget > 0 ? spent / budget : 0.0;

        Color progressColor = Colors.green;
        if (progress >= 1.0) {
          progressColor = Colors.red;
        } else if (progress > 0.8) {
          progressColor = Colors.orange;
        }

        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return Opacity(
          opacity: isHistory ? 0.7 : 1.0,
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventDetailScreen(event: event),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: isHistory
                    ? Border.all(color: Colors.grey.withValues(alpha: 0.2))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 12,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat(
                                    'dd MMM yyyy',
                                  ).format(event.startDate),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: event.status == 'Active'
                              ? Colors.green.withValues(alpha: 0.1)
                              : (event.status == 'Completed'
                                    ? Colors.blue.withValues(alpha: 0.1)
                                    : Colors.red.withValues(alpha: 0.1)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          event.status == 'Active'
                              ? 'Aktif'
                              : (event.status == 'Completed'
                                    ? 'Selesai'
                                    : event.status),
                          style: TextStyle(
                            color: event.status == 'Active'
                                ? Colors.green
                                : (event.status == 'Completed'
                                      ? Colors.blue
                                      : Colors.red),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress > 1.0 ? 1.0 : progress,
                    backgroundColor: isDarkMode
                        ? Colors.grey[700]
                        : Colors.grey[200],
                    color: progressColor,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Terpakai: ${currencyFormatter.format(spent)}',
                        style: TextStyle(
                          color: progressColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'dari ${currencyFormatter.format(budget)}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
