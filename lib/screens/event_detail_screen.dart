import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../providers/dashboard_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../widgets/transaction_item_card.dart';
import '../utils/currency_format.dart';

class EventDetailScreen extends ConsumerWidget {
  final Event event;

  const EventDetailScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final p = context.palette;
    final eventAsync = ref.watch(eventByIdProvider(event.id));
    final txAsync = ref.watch(transactionsByEventProvider(event.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(event.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditDialog(context, ref, event),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (liveEvent) => txAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (transactions) {
            int totalExpense = 0;
            for (final item in transactions) {
              if (item.transaction.type == 'Expense') {
                totalExpense += item.transaction.amount;
              }
            }

            final budget = liveEvent.budgetLimit;
            final remaining = budget - totalExpense;
            final progress = budget > 0
                ? (totalExpense / budget).clamp(0.0, 1.0)
                : 0.0;
            final isOver = remaining < 0;
            final barColor = isOver
                ? p.expense
                : progress > 0.8
                ? p.accent
                : p.income;

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: HeroPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AppBadge(
                                text: liveEvent.status == 'Active'
                                    ? 'Aktif'
                                    : liveEvent.status == 'Finished'
                                    ? 'Selesai'
                                    : liveEvent.status,
                                color: Colors.white,
                              ),
                              const Spacer(),
                              Text(
                                'Anggaran ${fmt.format(budget)}',
                                style: context.texts.labelSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.date_range_rounded,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${DateFormat('dd MMM yy').format(liveEvent.startDate)}'
                                '${liveEvent.endDate != null ? ' — ${DateFormat('dd MMM yy').format(liveEvent.endDate!)}' : ' — sekarang'}',
                                style: context.texts.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isOver ? 'Kelebihan Anggaran' : 'Sisa Anggaran',
                            style: context.texts.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              fmt.format(remaining),
                              style: context.texts.displaySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.22,
                              ),
                              valueColor: AlwaysStoppedAnimation(barColor),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Terpakai ${(progress * 100).toStringAsFixed(1)}% dari anggaran',
                            style: context.texts.labelSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fade().slideY(
                    begin: -0.1,
                    end: 0,
                    duration: 380.ms,
                  ),
                ),
                if (transactions.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyState(
                      icon: Icons.event_note_outlined,
                      title: 'Belum ada transaksi',
                      message:
                          'Pengeluaran untuk event ini akan tampil di sini.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    sliver: SliverList.builder(
                      itemCount: transactions.length,
                      itemBuilder: (context, index) => TransactionItemCard(
                        item: transactions[index],
                      ).animate().fade(delay: (index * 30).ms).slideX(
                        begin: 0.05,
                        end: 0,
                        delay: (index * 30).ms,
                        duration: 300.ms,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final p = context.palette;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Event?'),
        content: const Text(
          'Transaksi terkait tidak dihapus, hanya dilepas dari event ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.expense,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref
          .read(transactionRepositoryProvider)
          .deleteEvent(event.id);
      invalidateAllData(ref);
      if (context.mounted) Navigator.pop(context);
    }
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, Event currentEvent) {
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
    final p = context.palette;
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
                decoration: const InputDecoration(
                  labelText: 'Nama Event',
                  prefixIcon: Icon(Icons.event_note_rounded),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _budgetController,
                decoration: const InputDecoration(
                  labelText: 'Anggaran',
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
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: const [
                  DropdownMenuItem(value: 'Active', child: Text('Aktif')),
                  DropdownMenuItem(value: 'Finished', child: Text('Selesai')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _status = val);
                },
              ),
              const SizedBox(height: 14),
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
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Mulai',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  child: Text(DateFormat('dd MMM yyyy').format(_startDate)),
                ),
              ),
              const SizedBox(height: 14),
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
                    labelText: 'Tanggal Selesai (opsional)',
                    prefixIcon: Icon(Icons.event_available_rounded),
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
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: p.brand,
            minimumSize: const Size(0, 44),
          ),
          onPressed: _save,
          child: const Text('Simpan'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(transactionRepositoryProvider);
    final cleanBudget =
        _budgetController.text.replaceAll(RegExp(r'[^0-9]'), '');

    await repo.updateEvent(
      id: widget.event.id,
      name: _nameController.text,
      budgetLimit: int.parse(cleanBudget),
      status: _status,
      startDate: _startDate,
      endDate: _endDate,
    );
    if (mounted) Navigator.pop(context);
  }
}
