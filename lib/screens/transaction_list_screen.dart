import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/dashboard_providers.dart';
import '../repositories/transaction_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../widgets/transaction_item_card.dart';
import 'add_transaction_screen.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen>
    with AutomaticKeepAliveClientMixin {
  DateTime _selectedMonth = DateTime.now();

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Transaksi',
                      style: context.texts.headlineSmall,
                    ),
                  ),
                  _MonthStepper(
                    label: DateFormat(
                      'MMM yyyy',
                      'id_ID',
                    ).format(_selectedMonth),
                    onPrev: _prevMonth,
                    onNext: _nextMonth,
                  ),
                  const SizedBox(width: 8),
                  _RoundIconButton(
                    icon: Icons.filter_list_rounded,
                    onTap: () => _showFilterSheet(context, ref),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (details) {
                  final v = details.primaryVelocity ?? 0;
                  if (v > 0) {
                    _prevMonth();
                  } else if (v < 0) {
                    _nextMonth();
                  }
                },
                child: transactionsAsync.when(
                  data: (allTransactions) {
                    final monthTransactions = allTransactions.where((t) {
                      final d = t.transaction.transactionDate;
                      return d.year == _selectedMonth.year &&
                          d.month == _selectedMonth.month;
                    }).toList();

                    int monthIncome = 0, monthExpense = 0;
                    for (final t in monthTransactions) {
                      if (t.transaction.type == 'Income') {
                        monthIncome += t.transaction.amount;
                      } else if (t.transaction.type == 'Expense') {
                        monthExpense += t.transaction.amount;
                      }
                    }

                    Widget content;
                    if (monthTransactions.isEmpty) {
                      content = EmptyState(
                        key: ValueKey(
                          'empty-${_selectedMonth.year}-${_selectedMonth.month}',
                        ),
                        icon: Icons.receipt_long_outlined,
                        title: 'Tidak ada transaksi',
                        message:
                            'Belum ada catatan untuk bulan ini. Tekan tombol + untuk menambah.',
                      );
                    } else {
                      final grouped = _groupTransactionsByDay(monthTransactions);
                      final sortedDays = grouped.keys.toList()
                        ..sort((a, b) => b.compareTo(a));

                      content = ListView(
                        key: ValueKey(
                          'list-${_selectedMonth.year}-${_selectedMonth.month}',
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                        children: [
                          _MonthSummary(
                            income: monthIncome,
                            expense: monthExpense,
                            fmt: fmt,
                          ),
                          const SizedBox(height: 20),
                          ...List.generate(sortedDays.length, (index) {
                            final day = sortedDays[index];
                            final dayTransactions = grouped[day] ?? [];
                            dayTransactions.sort(
                              (a, b) => b.transaction.transactionDate
                                  .compareTo(a.transaction.transactionDate),
                            );
                            int income = 0, expense = 0;
                            for (final t in dayTransactions) {
                              if (t.transaction.type == 'Income') {
                                income += t.transaction.amount;
                              } else if (t.transaction.type == 'Expense') {
                                expense += t.transaction.amount;
                              }
                            }
                            final net = income - expense;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _DayHeader(
                                  day: day,
                                  date: DateTime(
                                    _selectedMonth.year,
                                    _selectedMonth.month,
                                    day,
                                  ),
                                  net: net,
                                  fmt: fmt,
                                ),
                                ...dayTransactions.map(
                                  (t) => TransactionItemCard(item: t),
                                ),
                                const SizedBox(height: 14),
                              ],
                            ).animate().fade().slideY(
                              begin: 0.04,
                              end: 0,
                              delay: (index < 5 ? index * 60 : 0).ms,
                              duration: 380.ms,
                              curve: Curves.easeOut,
                            );
                          }),
                        ],
                      );
                    }

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: content,
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => EmptyState(
                    icon: Icons.error_outline,
                    title: 'Gagal memuat',
                    message: '$err',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Transaksi'),
      ).animate().scale(
        delay: 250.ms,
        curve: Curves.elasticOut,
        duration: 600.ms,
      ),
    );
  }

  void _prevMonth() => setState(() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
  });

  void _nextMonth() => setState(() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
  });

  Map<int, List<TransactionWithDetails>> _groupTransactionsByDay(
    List<TransactionWithDetails> list,
  ) {
    final Map<int, List<TransactionWithDetails>> groups = {};
    for (final item in list) {
      final day = item.transaction.transactionDate.day;
      groups.putIfAbsent(day, () => []).add(item);
    }
    return groups;
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _FilterSheet(),
    );
  }
}

// ---------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------

class _MonthStepper extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthStepper({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _step(context, Icons.chevron_left_rounded, onPrev),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(label, style: context.texts.labelLarge),
          ),
          _step(context, Icons.chevron_right_rounded, onNext),
        ],
      ),
    );
  }

  Widget _step(BuildContext context, IconData icon, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 19, color: context.palette.textMuted),
        ),
      );
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: p.border),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 19, color: p.textMuted),
        ),
      ),
    );
  }
}

class _MonthSummary extends StatelessWidget {
  final int income;
  final int expense;
  final NumberFormat fmt;

  const _MonthSummary({
    required this.income,
    required this.expense,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatTile(
            label: 'Pemasukan',
            value: fmt.format(income),
            icon: Icons.south_west_rounded,
            color: context.palette.income,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatTile(
            label: 'Pengeluaran',
            value: fmt.format(expense),
            icon: Icons.north_east_rounded,
            color: context.palette.expense,
          ),
        ),
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  final int day;
  final DateTime date;
  final int net;
  final NumberFormat fmt;

  const _DayHeader({
    required this.day,
    required this.date,
    required this.net,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final negative = net < 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: p.border),
            ),
            child: Text(
              day.toString().padLeft(2, '0'),
              style: context.texts.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE', 'id_ID').format(date),
                  style: context.texts.titleSmall,
                ),
                Text(
                  DateFormat('MMMM yyyy', 'id_ID').format(date),
                  style: context.texts.bodySmall?.copyWith(color: p.textMuted),
                ),
              ],
            ),
          ),
          AppBadge(
            text: '${negative ? '-' : '+'}${fmt.format(net.abs())}',
            color: negative ? p.expense : p.income,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// Filter sheet
// ---------------------------------------------------------------

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  DateTime? _startDate;
  DateTime? _endDate;
  int? _categoryId;
  int? _accountId;
  String? _type;

  @override
  void initState() {
    super.initState();
    final current = ref.read(transactionFilterProvider);
    _startDate = current.startDate;
    _endDate = current.endDate;
    _categoryId = current.categoryId;
    _accountId = current.accountId;
    _type = current.type;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final p = context.palette;

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filter Transaksi', style: context.texts.titleLarge),
                  TextButton(
                    onPressed: _resetFilters,
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _FieldLabel('Tanggal'),
              OutlinedButton.icon(
                onPressed: () => _pickDateRange(context),
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text(
                  _startDate == null
                      ? 'Pilih Rentang Tanggal'
                      : '${DateFormat('dd/MM/yy').format(_startDate!)} - ${_endDate != null ? DateFormat('dd/MM/yy').format(_endDate!) : '?'}',
                  style: context.texts.bodyMedium,
                ),
              ),
              const SizedBox(height: 20),
              const _FieldLabel('Tipe Transaksi'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _typeChip('Semua', null),
                  _typeChip('Pemasukan', 'Income'),
                  _typeChip('Pengeluaran', 'Expense'),
                  _typeChip('Transfer', 'Transfer'),
                ],
              ),
              const SizedBox(height: 20),
              const _FieldLabel('Kategori'),
              categoriesAsync.when(
                data: (cats) => DropdownButtonFormField<int>(
                  initialValue: _categoryId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua Kategori')),
                    ...cats.map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => const Text('Gagal memuat kategori'),
              ),
              const SizedBox(height: 20),
              const _FieldLabel('Akun / Dompet'),
              accountsAsync.when(
                data: (accs) => DropdownButtonFormField<int>(
                  initialValue: _accountId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Semua Akun')),
                    ...accs.map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)),
                    ),
                  ],
                  onChanged: (v) => setState(() => _accountId = v),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => const Text('Gagal memuat akun'),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    _applyFilters();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Terapkan Filter'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _typeChip(String label, String? value) {
    return ChoiceChip(
      label: Text(label),
      selected: _type == value,
      onSelected: (selected) {
        if (selected) setState(() => _type = value);
      },
    );
  }

  void _resetFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _categoryId = null;
      _accountId = null;
      _type = null;
    });
  }

  void _applyFilters() {
    ref.read(transactionFilterProvider.notifier).state = TransactionFilter(
      startDate: _startDate,
      endDate: _endDate,
      categoryId: _categoryId,
      accountId: _accountId,
      type: _type,
    );
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: context.texts.titleSmall),
    );
  }
}