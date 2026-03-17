import 'package:drift/drift.dart';
import 'package:rxdart/rxdart.dart';
import '../database/database.dart';
import '../models/dashboard_summary.dart';

class TransactionWithDetails {
  final Transaction transaction;
  final Account account;
  final Category category;
  final Account? destinationAccount;

  TransactionWithDetails({
    required this.transaction,
    required this.account,
    required this.category,
    this.destinationAccount,
  });
}

class TransactionRepository {
  final AppDatabase _db;
  static const String transferType = 'Transfer';
  static const String transferCategoryName = 'Transfer Antar Rekening';

  TransactionRepository(this._db);

  AppDatabase getDatabase() => _db;

  Future<void> _updateAccountBalance(int accountId, int delta) async {
    final account = await (_db.select(
      _db.accounts,
    )..where((tbl) => tbl.id.equals(accountId))).getSingle();

    await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(accountId)))
        .write(
          AccountsCompanion(
            currentBalance: Value(account.currentBalance + delta),
          ),
        );
  }

  Future<void> _applyTransactionBalance(
    Transaction transaction, {
    bool reverse = false,
  }) async {
    switch (transaction.type) {
      case 'Income':
        await _updateAccountBalance(
          transaction.accountId,
          reverse ? -transaction.amount : transaction.amount,
        );
        break;
      case 'Expense':
        await _updateAccountBalance(
          transaction.accountId,
          reverse ? transaction.amount : -transaction.amount,
        );
        break;
      case transferType:
        final destinationAccountId = transaction.transferAccountId;
        if (destinationAccountId == null) {
          throw Exception('Akun tujuan transfer wajib dipilih.');
        }
        if (destinationAccountId == transaction.accountId) {
          throw Exception('Akun sumber dan tujuan transfer tidak boleh sama.');
        }

        await _updateAccountBalance(
          transaction.accountId,
          reverse ? transaction.amount : -transaction.amount,
        );
        await _updateAccountBalance(
          destinationAccountId,
          reverse ? -transaction.amount : transaction.amount,
        );
        break;
      default:
        throw Exception('Tipe transaksi tidak didukung: ${transaction.type}');
    }
  }

  Future<int> getOrInsertTransferCategory() async {
    final existing = await (_db.select(_db.categories)..where(
      (tbl) =>
          tbl.name.equals(transferCategoryName) &
          tbl.type.equals(transferType),
    )).getSingleOrNull();

    if (existing != null) return existing.id;

    return _db.into(_db.categories).insert(
      CategoriesCompanion.insert(
        name: transferCategoryName,
        type: transferType,
      ),
    );
  }

  // 1. Create Transaction with Balance Update Logic
  Future<void> createTransaction(
    TransactionsCompanion entry,
    int accountId,
    int? eventId,
  ) async {
    await _db.transaction(() async {
      final isTransfer = entry.type.value == transferType;
      final destinationAccountId = isTransfer
          ? entry.transferAccountId.value
          : null;

      if (isTransfer) {
        if (destinationAccountId == null) {
          throw Exception('Akun tujuan transfer wajib dipilih.');
        }
        if (destinationAccountId == accountId) {
          throw Exception('Akun sumber dan tujuan transfer tidak boleh sama.');
        }
      }

      // a. Insert the transaction
      final transactionEntry = entry.copyWith(
        accountId: Value(accountId),
        eventId: Value(isTransfer ? null : eventId),
        transferAccountId: Value(isTransfer ? destinationAccountId : null),
      );

      final transaction = await _db
          .into(_db.transactions)
          .insertReturning(transactionEntry);

      await _applyTransactionBalance(transaction);
    });
  }

  // 1.5 Update Transaction
  Future<void> updateTransaction(TransactionsCompanion entry) async {
    await _db.transaction(() async {
      // a. Get Old Transaction
      final oldTx = await (_db.select(
        _db.transactions,
      )..where((t) => t.id.equals(entry.id.value))).getSingle();

      // b. Revert Old Balance
      await _applyTransactionBalance(oldTx, reverse: true);

      final isTransfer = entry.type.value == transferType;
      final newAccountId = entry.accountId.present
          ? entry.accountId.value
          : oldTx.accountId;
      final newEventId = entry.eventId.present ? entry.eventId.value : oldTx.eventId;
      final newTransferAccountId = entry.transferAccountId.present
          ? entry.transferAccountId.value
          : oldTx.transferAccountId;

      if (isTransfer) {
        if (newTransferAccountId == null) {
          throw Exception('Akun tujuan transfer wajib dipilih.');
        }
        if (newTransferAccountId == newAccountId) {
          throw Exception('Akun sumber dan tujuan transfer tidak boleh sama.');
        }
      }

      // c. Update Transaction Record
      final updatedEntry = entry.copyWith(
        eventId: Value(isTransfer ? null : newEventId),
        transferAccountId: Value(isTransfer ? newTransferAccountId : null),
      );

      await (_db.update(
        _db.transactions,
      )..where((t) => t.id.equals(entry.id.value))).write(updatedEntry);

      // d. Apply New Balance
      final newTx = await (_db.select(
        _db.transactions,
      )..where((t) => t.id.equals(entry.id.value))).getSingle();

      await _applyTransactionBalance(newTx);
    });
  }

  // 2. Delete Transaction with Balance Reversal Logic
  Future<void> deleteTransaction(Transaction transaction) async {
    await _db.transaction(() async {
      // a. Reverse the balance calculation
      await _applyTransactionBalance(transaction, reverse: true);

      // c. Delete the transaction row
      await (_db.delete(
        _db.transactions,
      )..where((tbl) => tbl.id.equals(transaction.id))).go();
    });
  }

  // 3. Get Dashboard Summary
  Stream<DashboardSummary> getDashboardSummary() {
    // Stream 1: Total Balance of all accounts
    final balanceStream =
        (_db.selectOnly(_db.accounts)
              ..addColumns([_db.accounts.currentBalance.sum()]))
            .watchSingle()
            .map((row) => row.read(_db.accounts.currentBalance.sum()) ?? 0);

    // Filter range: This Month
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    // Stream 2: Total Income (This Month)
    final incomeStream =
        (_db.selectOnly(_db.transactions)
              ..addColumns([_db.transactions.amount.sum()])
              ..where(
                _db.transactions.type.equals('Income') &
                    _db.transactions.transactionDate.isBetweenValues(
                      startOfMonth,
                      endOfMonth,
                    ),
              ))
            .watchSingle()
            .map((row) => row.read(_db.transactions.amount.sum()) ?? 0);

    // Stream 3: Total Expense (This Month)
    final expenseStream =
        (_db.selectOnly(_db.transactions)
              ..addColumns([_db.transactions.amount.sum()])
              ..where(
                _db.transactions.type.equals('Expense') &
                    _db.transactions.transactionDate.isBetweenValues(
                      startOfMonth,
                      endOfMonth,
                    ),
              ))
            .watchSingle()
            .map((row) => row.read(_db.transactions.amount.sum()) ?? 0);

    // Combine all 3 streams
    return Rx.combineLatest3(
      balanceStream,
      incomeStream,
      expenseStream,
      (balance, income, expense) => DashboardSummary(
        totalBalance: balance,
        totalIncome: income,
        totalExpense: expense,
      ),
    );
  }

  // 4. Watch Recent Transactions
  Stream<List<TransactionWithDetails>> watchRecentTransactions() {
    final transferAccounts = _db.alias(_db.accounts, 'transfer_accounts_recent');
    final query =
        _db.select(_db.transactions).join([
            leftOuterJoin(
              _db.accounts,
              _db.accounts.id.equalsExp(_db.transactions.accountId),
            ),
            leftOuterJoin(
              transferAccounts,
              transferAccounts.id.equalsExp(_db.transactions.transferAccountId),
            ),
            leftOuterJoin(
              _db.categories,
              _db.categories.id.equalsExp(_db.transactions.categoryId),
            ),
          ])
          ..orderBy([OrderingTerm.desc(_db.transactions.transactionDate)])
          ..limit(50);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithDetails(
          transaction: row.readTable(_db.transactions),
          account: row.readTable(_db.accounts),
          category: row.readTable(_db.categories),
          destinationAccount: row.readTableOrNull(transferAccounts),
        );
      }).toList();
    });
  }

  // 4.1 Watch Transactions by Account
  Stream<List<TransactionWithDetails>> watchTransactionsByAccount(
    int accountId,
  ) {
    final transferAccounts = _db.alias(
      _db.accounts,
      'transfer_accounts_by_account',
    );
    final query =
        _db.select(_db.transactions).join([
            leftOuterJoin(
              _db.accounts,
              _db.accounts.id.equalsExp(_db.transactions.accountId),
            ),
            leftOuterJoin(
              transferAccounts,
              transferAccounts.id.equalsExp(_db.transactions.transferAccountId),
            ),
            leftOuterJoin(
              _db.categories,
              _db.categories.id.equalsExp(_db.transactions.categoryId),
            ),
          ])
          ..where(
            _db.transactions.accountId.equals(accountId) |
                _db.transactions.transferAccountId.equals(accountId),
          )
          ..orderBy([OrderingTerm.desc(_db.transactions.transactionDate)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithDetails(
          transaction: row.readTable(_db.transactions),
          account: row.readTable(_db.accounts),
          category: row.readTable(_db.categories),
          destinationAccount: row.readTableOrNull(transferAccounts),
        );
      }).toList();
    });
  }

  // 4.2 Watch Transactions by Event
  Stream<List<TransactionWithDetails>> watchTransactionsByEvent(int eventId) {
    final transferAccounts = _db.alias(
      _db.accounts,
      'transfer_accounts_by_event',
    );
    final query =
        _db.select(_db.transactions).join([
            leftOuterJoin(
              _db.accounts,
              _db.accounts.id.equalsExp(_db.transactions.accountId),
            ),
            leftOuterJoin(
              transferAccounts,
              transferAccounts.id.equalsExp(_db.transactions.transferAccountId),
            ),
            leftOuterJoin(
              _db.categories,
              _db.categories.id.equalsExp(_db.transactions.categoryId),
            ),
          ])
          ..where(_db.transactions.eventId.equals(eventId))
          ..orderBy([OrderingTerm.desc(_db.transactions.transactionDate)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithDetails(
          transaction: row.readTable(_db.transactions),
          account: row.readTable(_db.accounts),
          category: row.readTable(_db.categories),
          destinationAccount: row.readTableOrNull(transferAccounts),
        );
      }).toList();
    });
  }

  // 4.3 Watch Transactions with Dynamic Filter
  Stream<List<TransactionWithDetails>> watchTransactionsWithFilter({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    int? accountId,
    String? type,
  }) {
    final transferAccounts = _db.alias(
      _db.accounts,
      'transfer_accounts_filtered',
    );
    final query = _db.select(_db.transactions).join([
      leftOuterJoin(
        _db.accounts,
        _db.accounts.id.equalsExp(_db.transactions.accountId),
      ),
      leftOuterJoin(
        transferAccounts,
        transferAccounts.id.equalsExp(_db.transactions.transferAccountId),
      ),
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ]);

    // Apply Filters
    if (startDate != null && endDate != null) {
      // Ensure end date covers the full day
      final finalEnd = DateTime(
        endDate.year,
        endDate.month,
        endDate.day,
        23,
        59,
        59,
      );
      query.where(
        _db.transactions.transactionDate.isBetweenValues(startDate, finalEnd),
      );
    }

    if (categoryId != null) {
      query.where(_db.transactions.categoryId.equals(categoryId));
    }

    if (accountId != null) {
      query.where(
        _db.transactions.accountId.equals(accountId) |
            _db.transactions.transferAccountId.equals(accountId),
      );
    }

    if (type != null) {
      query.where(_db.transactions.type.equals(type));
    }

    query.orderBy([OrderingTerm.desc(_db.transactions.transactionDate)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithDetails(
          transaction: row.readTable(_db.transactions),
          account: row.readTable(_db.accounts),
          category: row.readTable(_db.categories),
          destinationAccount: row.readTableOrNull(transferAccounts),
        );
      }).toList();
    });
  }

  // 5. Watch Expense Breakdown
  Stream<List<CategoryExpense>> watchExpenseBreakdown() {
    final query = _db.select(_db.transactions).join([
      innerJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ]);

    query.where(_db.transactions.type.equals('Expense'));

    return query.watch().map((rows) {
      final Map<String, int> totals = {};

      for (final row in rows) {
        final category = row.readTable(_db.categories);
        final transaction = row.readTable(_db.transactions);

        final current = totals[category.name] ?? 0;
        totals[category.name] = current + transaction.amount;
      }

      return totals.entries
          .map(
            (e) => CategoryExpense(categoryName: e.key, totalAmount: e.value),
          )
          .toList();
    });
  }

  // 6. Watch Events with Spending (Budget vs Actual)
  Stream<List<EventWithSpending>> watchEventsWithSpending() {
    return _db.select(_db.events).watch().switchMap((events) {
      if (events.isEmpty) return Stream.value([]);

      // For each event, watch the sum of expenses
      final streams = events.map((event) {
        final query = _db.selectOnly(_db.transactions)
          ..addColumns([_db.transactions.amount.sum()])
          ..where(
            _db.transactions.eventId.equals(event.id) &
                _db.transactions.type.equals('Expense'),
          );

        return query.watchSingle().map((row) {
          final spent = row.read(_db.transactions.amount.sum()) ?? 0;
          return EventWithSpending(event: event, spentAmount: spent);
        });
      });

      return Rx.combineLatestList(streams);
    });
  }

  // 7. Create Event
  Future<void> createEvent(EventsCompanion entry) async {
    await _db.into(_db.events).insert(entry);
  }

  // 8. Get Active Events (for Dropdown)
  Stream<List<Event>> watchActiveEvents() {
    return (_db.select(
      _db.events,
    )..where((t) => t.status.equals('Active'))).watch();
  }

  // 8.0.5 Watch Single Event
  Stream<Event> watchEventById(int id) {
    return (_db.select(
      _db.events,
    )..where((t) => t.id.equals(id))).watchSingle();
  }

  // 8.1 Update Event (Safe Version using Write)
  Future<void> updateEvent(EventsCompanion entry) async {
    // We use .write() targeting the specific ID to avoid primary key conflicts
    await (_db.update(
      _db.events,
    )..where((t) => t.id.equals(entry.id.value))).write(entry);
  }

  // 8.2 Delete Event (Safe)
  Future<void> deleteEvent(int eventId) async {
    await _db.transaction(() async {
      // 1. Decouple Transactions (Set eventId = null)
      await (_db.update(_db.transactions)
            ..where((t) => t.eventId.equals(eventId)))
          .write(const TransactionsCompanion(eventId: Value(null)));

      // 2. Delete Event
      await (_db.delete(_db.events)..where((t) => t.id.equals(eventId))).go();
    });
  }

  // --- MEMBER & CASH LOG SECTION ---

  // 9. Watch Members
  Stream<List<Member>> watchMembers() {
    return (_db.select(
      _db.members,
    )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  // 10. Create Member (Low Level)
  Future<void> createMember(MembersCompanion entry) async {
    await _db.into(_db.members).insert(entry);
  }

  // 10.1 Add Member (Simple)
  Future<int> addMember(String name, {String? phoneNumber}) async {
    return await _db
        .into(_db.members)
        .insert(
          MembersCompanion.insert(name: name, phoneNumber: phoneNumber ?? ''),
        );
  }

  // 10.2 Update Member
  Future<bool> updateMember(int id, String name, {String? phoneNumber}) async {
    return await (_db.update(_db.members)..where((t) => t.id.equals(id))).write(
          MembersCompanion(
            name: Value(name),
            phoneNumber: phoneNumber != null
                ? Value(phoneNumber)
                : const Value.absent(),
          ),
        ) >
        0;
  }

  // 10.3 Delete Member (Cascade)
  Future<int> deleteMember(int id) async {
    return await _db.transaction(() async {
      // 1. Delete Cash Logs for this member
      await (_db.delete(
        _db.cashLogs,
      )..where((t) => t.memberId.equals(id))).go();

      // 2. Delete Member
      return await (_db.delete(
        _db.members,
      )..where((t) => t.id.equals(id))).go();
    });
  }

  // 11. Cash Periods (NEW)
  Stream<List<CashPeriod>> watchCashPeriods() {
    return (_db.select(
      _db.cashPeriods,
    )..orderBy([(t) => OrderingTerm.desc(t.startDate)])).watch();
  }

  Future<void> createCashPeriod(CashPeriodsCompanion entry) async {
    await _db.into(_db.cashPeriods).insert(entry);
  }

  // 12. Watch Cash Logs (Filtered by Period)
  Stream<List<CashLog>> watchCashLogsByPeriod(int periodId) {
    return (_db.select(
      _db.cashLogs,
    )..where((t) => t.periodId.equals(periodId))).watch();
  }

  Stream<int> watchCollectedCashForPeriod(int periodId) {
    final query = _db.select(_db.cashLogs).join([
      innerJoin(
        _db.transactions,
        _db.cashLogs.transactionId.equalsExp(_db.transactions.id),
      ),
    ]);

    query.where(_db.cashLogs.periodId.equals(periodId));

    return query.watch().map((rows) {
      var total = 0;
      for (final row in rows) {
        final transaction = row.readTable(_db.transactions);
        total += transaction.amount;
      }
      return total;
    });
  }

  // Legacy/Fallback: Watch all cash logs
  Stream<List<CashLog>> watchCashLogs() {
    return _db.select(_db.cashLogs).watch();
  }

  // 13. Helper: Get or Create 'Uang Kas' Category
  Future<int> getOrInsertCashCategory() async {
    final existing = await (_db.select(
      _db.categories,
    )..where((tbl) => tbl.name.equals('Uang Kas'))).getSingleOrNull();

    if (existing != null) return existing.id;

    return await _db
        .into(_db.categories)
        .insert(CategoriesCompanion.insert(name: 'Uang Kas', type: 'Income'));
  }

  // 14. Pay Member Cash (Updated for PeriodId)
  Future<void> payMemberCash({
    required int memberId,
    required String memberName,
    String? periodLabel, // Optional if periodId provides name
    int? periodId, // NEW
    required int amount,
    required int accountId,
  }) async {
    await _db.transaction(() async {
      // 1. Ensure Category
      final categoryId = await getOrInsertCashCategory();

      // 2. Resolve Label
      String pLabel = periodLabel ?? 'Unknown Period';
      if (periodId != null && periodLabel == null) {
        final p = await (_db.select(
          _db.cashPeriods,
        )..where((t) => t.id.equals(periodId))).getSingle();
        pLabel = p.name;
      }

      // 3. Create Transaction
      final transactionEntry = TransactionsCompanion.insert(
        amount: amount,
        type: 'Income',
        transactionDate: DateTime.now(),
        description: 'Kas $pLabel - $memberName',
        accountId: accountId,
        categoryId: categoryId,
        memberId: Value(memberId),
      );

      final transactionId = await _db
          .into(_db.transactions)
          .insertReturning(transactionEntry);

      // Update Balance
      final account = await (_db.select(
        _db.accounts,
      )..where((tbl) => tbl.id.equals(accountId))).getSingle();

      final newBalance = account.currentBalance + amount;

      await (_db.update(_db.accounts)..where((tbl) => tbl.id.equals(accountId)))
          .write(AccountsCompanion(currentBalance: Value(newBalance)));

      // 4. Create CashLog Link
      await _db
          .into(_db.cashLogs)
          .insert(
            CashLogsCompanion.insert(
              memberId: memberId,
              transactionId: transactionId.id,
              periodLabel: Value(pLabel),
              periodId: Value(periodId),
            ),
          );
    });
  }

  // 15. Void (Uncheck) Member Cash
  Future<void> voidMemberCash({
    required int memberId,
    String? periodLabel,
    int? periodId,
  }) async {
    await _db.transaction(() async {
      // 1. Find the CashLog
      CashLog? log;
      if (periodId != null) {
        log =
            await (_db.select(_db.cashLogs)..where(
                  (tbl) =>
                      tbl.memberId.equals(memberId) &
                      tbl.periodId.equals(periodId),
                ))
                .getSingleOrNull();
      } else if (periodLabel != null) {
        log =
            await (_db.select(_db.cashLogs)..where(
                  (tbl) =>
                      tbl.memberId.equals(memberId) &
                      tbl.periodLabel.equals(periodLabel),
                ))
                .getSingleOrNull();
      }

      if (log == null) return;

      // 2. Find the Transaction to reverse balance
      final transaction = await (_db.select(
        _db.transactions,
      )..where((tbl) => tbl.id.equals(log!.transactionId))).getSingle();

      // 3. Reverse Balance
      final account = await (_db.select(
        _db.accounts,
      )..where((tbl) => tbl.id.equals(transaction.accountId))).getSingle();

      final newBalance = account.currentBalance - transaction.amount;

      await (_db.update(_db.accounts)
            ..where((tbl) => tbl.id.equals(transaction.accountId)))
          .write(AccountsCompanion(currentBalance: Value(newBalance)));

      // 4. Delete Transaction and Log
      await (_db.delete(
        _db.cashLogs,
      )..where((tbl) => tbl.id.equals(log!.id))).go();
      await (_db.delete(
        _db.transactions,
      )..where((tbl) => tbl.id.equals(transaction.id))).go();
    });
  }

  // --- REPORT SECTION ---
  // 15. Get Transactions by Date Range
  Future<List<TransactionWithDetails>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    // Ensure "end" covers the full day
    final finalEnd = DateTime(end.year, end.month, end.day, 23, 59, 59);
    final transferAccounts = _db.alias(
      _db.accounts,
      'transfer_accounts_report',
    );

    final query =
        _db.select(_db.transactions).join([
            leftOuterJoin(
              _db.accounts,
              _db.accounts.id.equalsExp(_db.transactions.accountId),
            ),
            leftOuterJoin(
              transferAccounts,
              transferAccounts.id.equalsExp(_db.transactions.transferAccountId),
            ),
            leftOuterJoin(
              _db.categories,
              _db.categories.id.equalsExp(_db.transactions.categoryId),
            ),
          ])
          ..where(
            _db.transactions.transactionDate.isBetweenValues(start, finalEnd),
          )
          ..orderBy([OrderingTerm.asc(_db.transactions.transactionDate)]);

    final rows = await query.get();

    return rows.map((row) {
      return TransactionWithDetails(
        transaction: row.readTable(_db.transactions),
        account: row.readTable(_db.accounts),
        category: row.readTable(_db.categories),
        destinationAccount: row.readTableOrNull(transferAccounts),
      );
    }).toList();
  }

  // --- MASTER DATA CRUD ---

  // Accounts
  Stream<List<Account>> watchAccounts() {
    return _db.select(_db.accounts).watch();
  }

  Future<void> createAccount(AccountsCompanion entry) async {
    await _db.into(_db.accounts).insert(entry);
  }

  Future<void> updateAccount(AccountsCompanion entry) async {
    await _db.update(_db.accounts).replace(entry);
  }

  Future<void> deleteAccountWithReplacement({
    required int accountId,
    required int replacementAccountId,
  }) async {
    if (accountId == replacementAccountId) {
      throw Exception('Akun pengganti harus berbeda.');
    }

    await _db.transaction(() async {
      final sourceAccount = await (_db.select(
        _db.accounts,
      )..where((t) => t.id.equals(accountId))).getSingle();

      final replacementAccount = await (_db.select(
        _db.accounts,
      )..where((t) => t.id.equals(replacementAccountId))).getSingle();

      await (_db.update(_db.transactions)
            ..where((t) => t.accountId.equals(accountId)))
          .write(
            TransactionsCompanion(accountId: Value(replacementAccountId)),
          );

      await (_db.update(_db.transactions)
            ..where((t) => t.transferAccountId.equals(accountId)))
          .write(
            TransactionsCompanion(
              transferAccountId: Value(replacementAccountId),
            ),
          );

      await (_db.update(_db.accounts)
            ..where((t) => t.id.equals(replacementAccountId)))
          .write(
            AccountsCompanion(
              currentBalance: Value(
                replacementAccount.currentBalance + sourceAccount.currentBalance,
              ),
            ),
          );

      await (_db.delete(_db.accounts)..where((t) => t.id.equals(accountId))).go();
    });
  }

  Future<void> deleteAccount(int id) async {
    await (_db.delete(_db.accounts)..where((t) => t.id.equals(id))).go();
  }

  // Categories
  Stream<List<Category>> watchCategories() {
    return _db.select(_db.categories).watch();
  }

  Future<void> createCategory(CategoriesCompanion entry) async {
    await _db.into(_db.categories).insert(entry);
  }

  Future<void> updateCategory(CategoriesCompanion entry) async {
    await _db.update(_db.categories).replace(entry);
  }

  Future<void> deleteCategory(int id) async {
    await (_db.delete(_db.categories)..where((t) => t.id.equals(id))).go();
  }
}

class CategoryExpense {
  final String categoryName;
  final int totalAmount;

  CategoryExpense({required this.categoryName, required this.totalAmount});
}

class EventWithSpending {
  final Event event;
  final int spentAmount;

  EventWithSpending({required this.event, required this.spentAmount});
}
