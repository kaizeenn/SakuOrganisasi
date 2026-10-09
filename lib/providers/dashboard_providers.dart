import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../repositories/transaction_repository.dart';
import '../models/dashboard_summary.dart';

// AppDatabase dipertahankan HANYA untuk fitur backup/restore lokal di Settings.
// Data utama aplikasi mengalir via API backend (MySQL) — semua user melihat data sama.
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// 2. TransactionRepository Provider (API-backed)
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

// 3. DashboardSummary Provider
final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) {
  return ref.watch(transactionRepositoryProvider).getDashboardSummary();
});

// 4. Recent Transactions Provider
final recentTransactionsProvider =
    FutureProvider<List<TransactionWithDetails>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchRecentTransactions();
});

// 5. Accounts Provider (Global)
final accountsProvider = FutureProvider<List<Account>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchAccounts();
});

// 6. Categories Provider (Global)
final categoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchCategories();
});

// 7. Expense Breakdown Provider
final expenseChartRangeProvider = StateProvider<ExpenseChartRange>((ref) {
  return ExpenseChartRange.currentMonth();
});

final expenseBreakdownProvider = FutureProvider<List<CategoryExpense>>((ref) {
  final range = ref.watch(expenseChartRangeProvider);
  return ref.watch(transactionRepositoryProvider).watchExpenseBreakdown(
    startDate: range.startDate,
    endDate: range.endDate,
    allHistory: range.key == 'all',
  );
});

class ExpenseChartRange {
  final String key;
  final String label;
  final DateTime? startDate;
  final DateTime? endDate;

  const ExpenseChartRange({
    required this.key,
    required this.label,
    this.startDate,
    this.endDate,
  });

  factory ExpenseChartRange.currentMonth() {
    final now = DateTime.now();
    return ExpenseChartRange.forMonth(now.year, now.month);
  }

  factory ExpenseChartRange.forMonth(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    return ExpenseChartRange(
      key: 'month_${year}_$month',
      label: DateFormat('MMMM yyyy', 'id_ID').format(firstDay),
      startDate: firstDay,
      endDate: DateTime(year, month + 1, 0, 23, 59, 59),
    );
  }

  static const allHistory = ExpenseChartRange(
    key: 'all',
    label: 'Semua histori',
  );

  bool get isCurrentMonth {
    final now = DateTime.now();
    return startDate?.year == now.year && startDate?.month == now.month;
  }
}

// 8. Events With Spending Provider
final eventsWithSpendingProvider =
    FutureProvider<List<EventWithSpending>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchEventsWithSpending();
});

// 9. Active Events Provider
final activeEventsProvider = FutureProvider<List<Event>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchActiveEvents();
});

// 10. Filter State Provider
final transactionFilterProvider = StateProvider<TransactionFilter>((ref) {
  return TransactionFilter();
});

class TransactionFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final int? categoryId;
  final int? accountId;
  final String? type;

  TransactionFilter({
    this.startDate,
    this.endDate,
    this.categoryId,
    this.accountId,
    this.type,
  });

  TransactionFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    int? accountId,
    String? type,
  }) {
    return TransactionFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
    );
  }
}

// 11. Custom Filtered Transactions Provider
final filteredTransactionsProvider =
    FutureProvider<List<TransactionWithDetails>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  final filter = ref.watch(transactionFilterProvider);

  return repository.watchTransactionsWithFilter(
    startDate: filter.startDate,
    endDate: filter.endDate,
    categoryId: filter.categoryId,
    accountId: filter.accountId,
    type: filter.type,
  );
});

// 12. Cash Periods Provider
final cashPeriodsProvider = FutureProvider<List<CashPeriod>>((ref) {
  return ref.watch(transactionRepositoryProvider).watchCashPeriods();
});

// 13. Family providers (detail screens)
final transactionsByAccountProvider = FutureProvider.family<
    List<TransactionWithDetails>, int>((ref, accountId) {
  return ref
      .watch(transactionRepositoryProvider)
      .watchTransactionsByAccount(accountId);
});

final transactionsByEventProvider = FutureProvider.family<
    List<TransactionWithDetails>, int>((ref, eventId) {
  return ref
      .watch(transactionRepositoryProvider)
      .watchTransactionsByEvent(eventId);
});

final eventByIdProvider = FutureProvider.family<Event, int>((ref, id) {
  return ref.watch(transactionRepositoryProvider).watchEventById(id);
});

final cashChecklistProvider =
    FutureProvider.family<CashChecklist, int>((ref, periodId) {
  return ref.watch(transactionRepositoryProvider).getChecklist(periodId);
});

final collectedCashProvider =
    FutureProvider.family<int, int>((ref, periodId) {
  return ref
      .watch(transactionRepositoryProvider)
      .watchCollectedCashForPeriod(periodId);
});

/// Invalidate semua provider yang berkaitan dengan data keuangan agar di-fetch ulang
/// dari server setelah mutasi (create/update/delete). Panggil dari screen setelah
/// operasi berhasil.
void invalidateAllData(WidgetRef ref) {
  ref.invalidate(dashboardSummaryProvider);
  ref.invalidate(recentTransactionsProvider);
  ref.invalidate(accountsProvider);
  ref.invalidate(categoriesProvider);
  ref.invalidate(expenseBreakdownProvider);
  ref.invalidate(eventsWithSpendingProvider);
  ref.invalidate(activeEventsProvider);
  ref.invalidate(filteredTransactionsProvider);
  ref.invalidate(cashPeriodsProvider);
}
