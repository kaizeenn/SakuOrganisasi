import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../repositories/transaction_repository.dart';
import '../models/dashboard_summary.dart';

// 1. Database Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// 2. TransactionRepository Provider
final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TransactionRepository(db);
});

// 3. DashboardSummary Provider
final dashboardSummaryProvider = StreamProvider<DashboardSummary>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.getDashboardSummary();
});

// 4. Recent Transactions Provider
final recentTransactionsProvider = StreamProvider<List<TransactionWithDetails>>(
  (ref) {
    final repository = ref.watch(transactionRepositoryProvider);
    return repository.watchRecentTransactions();
  },
);

// 5. Accounts Provider (Global)
final accountsProvider = StreamProvider<List<Account>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.accounts).watch();
});

// 6. Categories Provider (Global)
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.categories).watch();
});

// 7. Expense Breakdown Provider
final expenseBreakdownProvider = StreamProvider<List<CategoryExpense>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.watchExpenseBreakdown();
});

// 8. Events With Spending Provider
final eventsWithSpendingProvider = StreamProvider<List<EventWithSpending>>((
  ref,
) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.watchEventsWithSpending();
});

// 9. Active Events Provider
final activeEventsProvider = StreamProvider<List<Event>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.watchActiveEvents();
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
    StreamProvider<List<TransactionWithDetails>>((ref) {
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
final cashPeriodsProvider = StreamProvider<List<CashPeriod>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.watchCashPeriods();
});
