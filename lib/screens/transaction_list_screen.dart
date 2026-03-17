import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/dashboard_providers.dart';
import '../repositories/transaction_repository.dart';
import 'add_transaction_screen.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  const TransactionListScreen({super.key});

  @override
  ConsumerState<TransactionListScreen> createState() =>
      _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    // 1. Watch Filtered Transactions (from global provider)
    final transactionsAsync = ref.watch(filteredTransactionsProvider);
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Filter local data by Month/Year
    // Note: If global filter restricts this, it will show empty.
    // This is expected behavior for "Advanced Filter" combination.

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _prevMonth,
            ),
            Text(
              DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _nextMonth,
            ),
          ],
        ),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context, ref),
          ),
        ],
      ),
      body: GestureDetector(
        behavior:
            HitTestBehavior.translucent, // FIX: Detect swipes on empty space
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            // Swipe Right -> Previous Month
            _prevMonth();
          } else if (details.primaryVelocity! < 0) {
            // Swipe Left -> Next Month
            _nextMonth();
          }
        },
        child: transactionsAsync.when(
          data: (allTransactions) {
            // 1. Filter by Selected Month
            final monthTransactions = allTransactions.where((t) {
              final d = t.transaction.transactionDate;
              return d.year == _selectedMonth.year &&
                  d.month == _selectedMonth.month;
            }).toList();

            Widget content;
            if (monthTransactions.isEmpty) {
              content = Center(
                key: ValueKey(
                  'empty-${_selectedMonth.year}-${_selectedMonth.month}',
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 48,
                      color: isDarkMode ? Colors.white38 : Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Tidak ada transaksi bulan ini',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white38 : Colors.grey,
                      ),
                    ),
                  ],
                ).animate().fade(),
              );
            } else {
              // 2. Group by Day
              final grouped = _groupTransactionsByDay(monthTransactions);
              final sortedDays = grouped.keys.toList()
                ..sort((a, b) => b.compareTo(a)); // Descending

              content = ListView.builder(
                key: ValueKey(
                  'list-${_selectedMonth.year}-${_selectedMonth.month}',
                ),
                padding: const EdgeInsets.only(bottom: 80), // Fab space
                itemCount: sortedDays.length,
                itemBuilder: (context, index) {
                  final day = sortedDays[index];
                  final dayTransactions = grouped[day] ?? [];

                  // Sort txns within day (Newest First)
                  dayTransactions.sort(
                    (a, b) => b.transaction.transactionDate.compareTo(
                      a.transaction.transactionDate,
                    ),
                  );

                  // Calculate Day Total (Net)
                  int income = 0;
                  int expense = 0;
                  for (var t in dayTransactions) {
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
                      // Day Header
                      _buildDayHeader(day, net, currencyFormatter, isDarkMode),
                      // Transaction Tiles
                      ...dayTransactions.map(
                        (item) => _buildTransactionItem(
                          context,
                          ref,
                          item,
                          currencyFormatter,
                          isDarkMode,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ).animate().fade().slideY(
                    delay: (index < 5 ? index * 50 : 0).ms,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  );
                },
              );
            }

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: content,
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add),
      ).animate().scale(delay: 300.ms, curve: Curves.elasticOut),
    );
  }

  void _prevMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    });
  }

  Map<int, List<TransactionWithDetails>> _groupTransactionsByDay(
    List<TransactionWithDetails> list,
  ) {
    final Map<int, List<TransactionWithDetails>> groups = {};
    for (var item in list) {
      final day = item.transaction.transactionDate.day;
      if (!groups.containsKey(day)) {
        groups[day] = [];
      }
      groups[day]!.add(item);
    }
    return groups;
  }

  Widget _buildDayHeader(
    int day,
    int netAmount,
    NumberFormat fmt,
    bool isDarkMode,
  ) {
    // Construct Date Object for formatting
    final date = DateTime(_selectedMonth.year, _selectedMonth.month, day);

    final dayName = DateFormat('EEEE', 'id_ID').format(date);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                day.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    DateFormat('MMMM yyyy', 'id_ID').format(date),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          Text(
            fmt.format(netAmount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: netAmount >= 0 ? Colors.green : Colors.red,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(
    BuildContext context,
    WidgetRef ref,
    TransactionWithDetails item,
    NumberFormat fmt,
    bool isDarkMode,
  ) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final isTransfer = item.transaction.type == 'Transfer';
    final transactionColor = isTransfer
        ? Colors.blue
        : item.transaction.type == 'Income'
        ? Colors.green
        : Colors.red;
    final transactionIcon = isTransfer
        ? Icons.swap_horiz
        : item.transaction.type == 'Income'
        ? Icons.arrow_downward
        : Icons.arrow_upward;
    final title = item.transaction.description.isEmpty
        ? isTransfer
              ? 'Transfer Saldo'
              : item.category.name
        : item.transaction.description;
    final subtitle = isTransfer && item.destinationAccount != null
        ? '${item.account.name} → ${item.destinationAccount!.name}'
        : item.account.name;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddTransactionScreen(editTransaction: item),
            ),
          );
        },
        // Using Row to layout carefully
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: transactionColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                transactionIcon,
                color: transactionColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      if (item.transaction.proofImage != null) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.attach_file,
                          size: 14,
                          color: Colors.blue,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              fmt.format(item.transaction.amount),
              style: TextStyle(
                color: transactionColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _FilterSheet(),
    );
  }
}

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
  String? _type; // 'Income', 'Expense', or null

  @override
  void initState() {
    super.initState();
    // Load existing filter
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

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Transaksi',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      _resetFilters();
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Date Range - OPTIONAL as we now have Month View
              // Keeping it allows cross-month search if needed.
              const Text(
                'Tanggal',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDateRange(context),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _startDate == null
                            ? 'Pilih Rentang Tanggal'
                            : '${DateFormat('dd/MM/yy').format(_startDate!)} - ${_endDate != null ? DateFormat('dd/MM/yy').format(_endDate!) : "?"}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Type
              const Text(
                'Tipe Transaksi',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTypeChip('Semua', null),
                  _buildTypeChip('Pemasukan', 'Income'),
                  _buildTypeChip('Pengeluaran', 'Expense'),
                  _buildTypeChip('Transfer', 'Transfer'),
                ],
              ),
              const SizedBox(height: 20),

              // Category
              const Text(
                'Kategori',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              categoriesAsync.when(
                data: (cats) {
                  return DropdownButtonFormField<int>(
                    // ignore: deprecated_member_use
                    value: _categoryId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Semua Kategori'),
                      ),
                      ...cats.map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text('Error loading categories'),
              ),
              const SizedBox(height: 20),

              // Account
              const Text(
                'Akun / Dompet',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              accountsAsync.when(
                data: (accs) {
                  return DropdownButtonFormField<int>(
                    // ignore: deprecated_member_use
                    value: _accountId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Semua Akun'),
                      ),
                      ...accs.map(
                        (a) =>
                            DropdownMenuItem(value: a.id, child: Text(a.name)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _accountId = v),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, s) => Text('Error loading accounts'),
              ),
              const SizedBox(height: 32),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _applyFilters();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Terapkan Filter'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTypeChip(String label, String? value) {
    final isSelected = _type == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _type = value);
        }
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
