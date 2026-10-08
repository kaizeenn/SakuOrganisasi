import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../repositories/transaction_repository.dart';
import '../utils/currency_format.dart';
import 'event_detail_screen.dart';

class EventListScreen extends ConsumerWidget {
  const EventListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(eventsWithSpendingProvider);
    final p = context.palette;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kegiatan & Proker', style: context.texts.headlineSmall),
                          Text(
                            'Pantau anggaran tiap program kerja',
                            style: context.texts.bodySmall?.copyWith(
                              color: p.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => _showAddEventDialog(context, ref),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Baru'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: TabBar(
                  indicator: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: p.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: p.brand,
                  unselectedLabelColor: p.textMuted,
                  tabs: const [
                    Tab(height: 40, text: 'Berjalan'),
                    Tab(height: 40, text: 'Riwayat'),
                  ],
                ),
              ),
              Expanded(
                child: eventsAsync.when(
                  data: (events) {
                    final active = events
                        .where((e) => e.event.status == 'Active')
                        .toList();
                    final history = events
                        .where((e) => e.event.status != 'Active')
                        .toList();
                    return TabBarView(
                      children: [
                        _EventList(
                          events: active,
                          isEmptyMessage: 'Tidak ada kegiatan aktif.',
                          isHistory: false,
                        ),
                        _EventList(
                          events: history,
                          isEmptyMessage: 'Belum ada riwayat kegiatan.',
                          isHistory: true,
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => EmptyState(
                    icon: Icons.error_outline,
                    title: 'Gagal memuat',
                    message: '$err',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddEventDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    DateTime startDate = DateTime.now();
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Tambah Kegiatan'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Kegiatan',
                    prefixIcon: Icon(Icons.event_note_rounded),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: budgetController,
                  decoration: const InputDecoration(
                    labelText: 'Anggaran',
                    hintText: 'Rp 0',
                    prefixIcon: Icon(Icons.payments_rounded),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    RupiahInputFormatter(),
                  ],
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: 'Mulai',
                        date: startDate,
                        onPick: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => startDate = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(
                        label: 'Selesai',
                        date: endDate,
                        onPick: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate ?? startDate,
                            firstDate: startDate,
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => endDate = picked);
                        },
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
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final repo = ref.read(transactionRepositoryProvider);
                final clean = budgetController.text.replaceAll(
                  RegExp(r'[^0-9]'),
                  '',
                );
                await repo.createEvent(
                  name: nameController.text,
                  budgetLimit: int.parse(clean),
                  status: 'Active',
                  startDate: startDate,
                  endDate: endDate,
                );
                invalidateAllData(ref);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onPick;
  const _DateField({required this.label, required this.date, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        ),
        child: Text(
          date != null ? DateFormat('dd MMM yy').format(date!) : '-',
          style: context.texts.bodyMedium,
        ),
      ),
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
    final p = context.palette;
    if (events.isEmpty) {
      return EmptyState(
        icon: isHistory ? Icons.history_rounded : Icons.event_available_rounded,
        title: isEmptyMessage,
        message: isHistory ? null : 'Buat proker untuk mulai memantau anggaran.',
      );
    }

    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final item = events[index];
        final event = item.event;
        final spent = item.spentAmount;
        final budget = event.budgetLimit;
        final progress = budget > 0 ? (spent / budget) : 0.0;
        final over = progress >= 1.0;
        final warn = progress > 0.8 && !over;
        final color = over
            ? p.expense
            : warn
            ? p.accent
            : p.income;

        final statusLabel = event.status == 'Active'
            ? 'Aktif'
            : event.status == 'Completed'
            ? 'Selesai'
            : 'Dibatalkan';
        final statusColor = event.status == 'Active'
            ? p.income
            : event.status == 'Completed'
            ? p.transfer
            : p.expense;

        return Opacity(
          opacity: isHistory ? 0.82 : 1.0,
          child: AppCard(
            margin: const EdgeInsets.only(bottom: 14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EventDetailScreen(event: event),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.texts.titleMedium,
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppBadge(text: statusLabel, color: statusColor),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 12, color: p.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      '${DateFormat('dd MMM yyyy').format(event.startDate)}'
                      '${event.endDate != null ? ' — ${DateFormat('dd MMM yyyy').format(event.endDate!)}' : ''}',
                      style: context.texts.bodySmall?.copyWith(color: p.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress > 1.0 ? 1.0 : progress,
                    minHeight: 9,
                    backgroundColor: p.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Terpakai ${fmt.format(spent)}',
                      style: context.texts.labelSmall?.copyWith(color: color),
                    ),
                    const Spacer(),
                    Text(
                      'dari ${fmt.format(budget)}',
                      style: context.texts.labelSmall?.copyWith(
                        color: p.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fade(delay: (index * 60).ms, duration: 380.ms).slideY(
          begin: 0.05,
          end: 0,
          delay: (index * 60).ms,
          duration: 380.ms,
        );
      },
    );
  }
}
