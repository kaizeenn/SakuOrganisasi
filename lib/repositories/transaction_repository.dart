// Repository berbasis API backend (MySQL) — bukan Drift/SQLite lokal.
// Semua data lewat ApiClient → backend Express → MySQL. Sehingga semua user
// (bendahara) melihat data yang sama. Method "watch*" mengembalikan Future
// (HTTP request-response); provider Riverpod memakai FutureProvider +
// invalidate saat ada mutasi.
import '../database/database.dart';
import '../models/dashboard_summary.dart';
import '../services/api_client.dart';

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

/// Checklist item untuk kas per periode (dari GET /api/cash/periods/:id/checklist).
class CashChecklistItem {
  final int memberId;
  final String memberName;
  final String phoneNumber;
  final bool paid;
  final int amount;
  final int? transactionId;
  final int? cashLogId;
  final DateTime? paidAt;

  CashChecklistItem({
    required this.memberId,
    required this.memberName,
    required this.phoneNumber,
    required this.paid,
    required this.amount,
    this.transactionId,
    this.cashLogId,
    this.paidAt,
  });
}

class CashChecklist {
  final CashPeriod period;
  final List<CashChecklistItem> items;
  final int totalMembers;
  final int paidCount;
  final int unpaidCount;
  final int totalCollected;

  CashChecklist({
    required this.period,
    required this.items,
    required this.totalMembers,
    required this.paidCount,
    required this.unpaidCount,
    required this.totalCollected,
  });
}

class TransactionRepository {
  static const String transferType = 'Transfer';
  static const String transferCategoryName = 'Transfer Antar Rekening';

  final ApiClient _api = ApiClient.instance;

  // ============ Mappers JSON → Drift model ============

  Account _mapAccount(Map<String, dynamic> m) => Account(
        id: (m['id'] as num).toInt(),
        name: (m['name'] ?? '') as String,
        type: (m['type'] ?? 'Bank') as String,
        initialBalance: (m['initialBalance'] as num?)?.toInt() ?? 0,
        currentBalance: (m['currentBalance'] as num?)?.toInt() ??
            (m['balance'] as num?)?.toInt() ??
            0,
        iconKey: (m['iconKey'] as String?) ?? 'default',
      );

  Category _mapCategory(Map<String, dynamic> m) => Category(
        id: (m['id'] as num).toInt(),
        name: (m['name'] ?? '') as String,
        type: (m['type'] ?? 'Expense') as String,
        iconKey: (m['iconKey'] as String?) ?? 'default',
      );

  Member _mapMember(Map<String, dynamic> m) => Member(
        id: (m['id'] as num).toInt(),
        name: (m['name'] ?? '') as String,
        phoneNumber: (m['phoneNumber'] as String?) ?? '',
      );

  Event _mapEvent(Map<String, dynamic> m) => Event(
        id: (m['id'] as num).toInt(),
        name: (m['name'] ?? '') as String,
        budgetLimit: (m['budgetLimit'] as num?)?.toInt() ?? 0,
        status: (m['status'] ?? 'Active') as String,
        startDate: _parseDate(m['startDate']) ?? DateTime.now(),
        endDate: _parseDate(m['endDate']),
      );

  CashPeriod _mapCashPeriod(Map<String, dynamic> m) => CashPeriod(
        id: (m['id'] as num).toInt(),
        name: (m['name'] ?? '') as String,
        startDate: _parseDate(m['startDate']) ?? DateTime.now(),
        endDate: _parseDate(m['endDate']) ?? DateTime.now(),
        status: (m['status'] ?? 'Active') as String,
        createdAt: _parseDate(m['createdAt']) ?? DateTime.now(),
      );

  CashLog _mapCashLog(Map<String, dynamic> m) {
    final period = m['period'] as Map<String, dynamic>?;
    return CashLog(
      id: (m['id'] as num).toInt(),
      memberId: (m['memberId'] as num).toInt(),
      transactionId: (m['transactionId'] as num).toInt(),
      periodLabel:
          (m['periodLabel'] as String?) ?? (period?['name'] as String?),
      periodId: m['periodId'] as int?,
    );
  }

  Transaction _mapTransaction(Map<String, dynamic> m) {
    return Transaction(
      id: (m['id'] as num).toInt(),
      amount: (m['amount'] as num).toInt(),
      type: (m['type'] ?? 'Expense') as String,
      transactionDate: _parseDate(m['transactionDate']) ?? DateTime.now(),
      description: (m['description'] as String?) ?? '',
      accountId: (m['accountId'] as num).toInt(),
      transferAccountId: m['transferAccountId'] as int?,
      categoryId: (m['categoryId'] as num).toInt(),
      eventId: m['eventId'] as int?,
      memberId: m['memberId'] as int?,
      proofImage: m['proofImage'] as String?,
    );
  }

  TransactionWithDetails _mapTxWithDetails(Map<String, dynamic> m) {
    return TransactionWithDetails(
      transaction: _mapTransaction(m),
      account: _mapAccount(m['account'] as Map<String, dynamic>),
      category: _mapCategory(m['category'] as Map<String, dynamic>),
      destinationAccount: m['transferAccount'] != null
          ? _mapAccount(m['transferAccount'] as Map<String, dynamic>)
          : null,
    );
  }

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  // ============ Dashboard ============

  Future<DashboardSummary> getDashboardSummary() async {
    final res = await _api.get('/api/dashboard/summary');
    final d = res['data'] as Map<String, dynamic>;
    return DashboardSummary(
      totalBalance: (d['totalBalance'] as num).toInt(),
      totalIncome: (d['totalIncome'] as num).toInt(),
      totalExpense: (d['totalExpense'] as num).toInt(),
    );
  }

  Future<List<Account>> getAccountsForHero() async {
    final res = await _api.get('/api/dashboard/summary');
    final list = (res['data']['accounts'] as List)
        .map((e) => Account(
              id: (e['id'] as num).toInt(),
              name: (e['name'] ?? '') as String,
              type: (e['type'] ?? 'Bank') as String,
              initialBalance: 0,
              currentBalance: (e['balance'] as num).toInt(),
              iconKey: 'default',
            ))
        .toList();
    return list;
  }

  // ============ Accounts ============

  Future<List<Account>> watchAccounts() async {
    final res = await _api.get('/api/accounts');
    final list = (res['data']['accounts'] as List)
        .map((e) => _mapAccount(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<Account> createAccount({
    required String name,
    required String type,
    int initialBalance = 0,
    String iconKey = 'default',
  }) async {
    final res = await _api.post('/api/accounts', body: {
      'name': name,
      'type': type,
      'initialBalance': initialBalance,
      'currentBalance': initialBalance,
      'iconKey': iconKey,
    });
    return _mapAccount(res['data']['account'] as Map<String, dynamic>);
  }

  Future<void> updateAccount({
    required int id,
    required String name,
    required String type,
    int? initialBalance,
    int? currentBalance,
    String? iconKey,
  }) async {
    await _api.patch('/api/accounts/$id', body: {
      'name': name,
      'type': type,
      if (initialBalance != null) 'initialBalance': initialBalance,
      if (currentBalance != null) 'currentBalance': currentBalance,
      if (iconKey != null) 'iconKey': iconKey,
    });
  }

  Future<void> deleteAccount(int id) async {
    await _api.delete('/api/accounts/$id');
  }

  // ============ Categories ============

  Future<List<Category>> watchCategories() async {
    final res = await _api.get('/api/categories');
    final list = (res['data']['categories'] as List)
        .map((e) => _mapCategory(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<Category> createCategory({
    required String name,
    required String type,
    String iconKey = 'default',
  }) async {
    final res = await _api.post('/api/categories', body: {
      'name': name,
      'type': type,
      'iconKey': iconKey,
    });
    return _mapCategory(res['data']['category'] as Map<String, dynamic>);
  }

  Future<void> updateCategory({
    required int id,
    String? name,
    String? type,
    String? iconKey,
  }) async {
    await _api.patch('/api/categories/$id', body: {
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (iconKey != null) 'iconKey': iconKey,
    });
  }

  Future<void> deleteCategory(int id) async {
    await _api.delete('/api/categories/$id');
  }

  Future<int> getOrInsertTransferCategory() async {
    final cats = await watchCategories();
    final existing = cats.firstWhere(
      (c) => c.name == transferCategoryName && c.type == transferType,
      orElse: () => Category(
          id: 0, name: '', type: '', iconKey: 'default'),
    );
    if (existing.id != 0) return existing.id;
    final created = await createCategory(
      name: transferCategoryName,
      type: transferType,
    );
    return created.id;
  }

  Future<void> ensureTransferCategoryExists() async {
    await getOrInsertTransferCategory();
  }

  // ============ Members ============

  Future<List<Member>> watchMembers() async {
    final res = await _api.get('/api/members');
    final list = (res['data']['members'] as List)
        .map((e) => _mapMember(e as Map<String, dynamic>))
        .toList();
    // sort by name (backend mungkin urut beda)
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Future<Member> createMember({
    required String name,
    String phoneNumber = '',
  }) async {
    final res = await _api.post('/api/members', body: {
      'name': name,
      'phoneNumber': phoneNumber,
    });
    return _mapMember(res['data']['member'] as Map<String, dynamic>);
  }

  Future<int> addMember(String name, {String? phoneNumber}) async {
    final m = await createMember(name: name, phoneNumber: phoneNumber ?? '');
    return m.id;
  }

  Future<bool> updateMember(int id, String name, {String? phoneNumber}) async {
    await _api.patch('/api/members/$id', body: {
      'name': name,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
    });
    return true;
  }

  Future<int> deleteMember(int id) async {
    await _api.delete('/api/members/$id');
    return 1;
  }

  // ============ Events ============

  Future<List<Event>> watchActiveEvents() async {
    final res = await _api.get('/api/events', q: {'status': 'Active'});
    final list = (res['data']['events'] as List)
        .map((e) => _mapEvent(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<List<Event>> watchAllEvents() async {
    final res = await _api.get('/api/events');
    final list = (res['data']['events'] as List)
        .map((e) => _mapEvent(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<Event> watchEventById(int id) async {
    final res = await _api.get('/api/events/$id');
    return _mapEvent(res['data']['event'] as Map<String, dynamic>);
  }

  Future<Event> createEvent({
    required String name,
    int budgetLimit = 0,
    String status = 'Active',
    required DateTime startDate,
    DateTime? endDate,
  }) async {
    final res = await _api.post('/api/events', body: {
      'name': name,
      'budgetLimit': budgetLimit,
      'status': status,
      'startDate': startDate.toUtc().toIso8601String(),
      'endDate': endDate?.toUtc().toIso8601String(),
    });
    return _mapEvent(res['data']['event'] as Map<String, dynamic>);
  }

  Future<void> updateEvent({
    required int id,
    String? name,
    int? budgetLimit,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await _api.patch('/api/events/$id', body: {
      if (name != null) 'name': name,
      if (budgetLimit != null) 'budgetLimit': budgetLimit,
      if (status != null) 'status': status,
      if (startDate != null) 'startDate': startDate.toUtc().toIso8601String(),
      if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
    });
  }

  Future<void> deleteEvent(int eventId) async {
    await _api.delete('/api/events/$eventId');
  }

  Future<List<EventWithSpending>> watchEventsWithSpending() async {
    final events = await watchAllEvents();
    if (events.isEmpty) return [];
    // Fetch all expense transactions (sampai 200) lalu group by eventId.
    final res = await _api.get('/api/transactions', q: {
      'type': 'Expense',
      'limit': '200',
    });
    final txs = (res['data']['transactions'] as List)
        .where((t) => (t as Map<String, dynamic>)['eventId'] != null)
        .toList();
    final spent = <int, int>{};
    for (final t in txs) {
      final eid = (t as Map<String, dynamic>)['eventId'] as int;
      spent[eid] = (spent[eid] ?? 0) + (t['amount'] as num).toInt();
    }
    return events
        .map((e) => EventWithSpending(event: e, spentAmount: spent[e.id] ?? 0))
        .toList();
  }

  // ============ Transactions ============

  Future<List<TransactionWithDetails>> watchRecentTransactions() async {
    final res = await _api.get('/api/transactions', q: {'limit': '50'});
    final list = (res['data']['transactions'] as List)
        .map((e) => _mapTxWithDetails(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<List<TransactionWithDetails>> watchTransactionsByAccount(
    int accountId,
  ) async {
    final res = await _api.get('/api/transactions', q: {
      'accountId': accountId.toString(),
      'limit': '200',
    });
    // Backend filter hanya accountId; transfer masuk via transferAccountId
    // tidak ter-cover filter tunggal → kita juga ambil lalu saring lokal.
    final list = (res['data']['transactions'] as List)
        .map((e) => _mapTxWithDetails(e as Map<String, dynamic>))
        .where((t) =>
            t.transaction.accountId == accountId ||
            t.transaction.transferAccountId == accountId)
        .toList();
    return list;
  }

  Future<List<TransactionWithDetails>> watchTransactionsByEvent(int eventId) async {
    final res = await _api.get('/api/transactions', q: {
      'eventId': eventId.toString(),
      'limit': '200',
    });
    final list = (res['data']['transactions'] as List)
        .map((e) => _mapTxWithDetails(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<List<TransactionWithDetails>> watchTransactionsWithFilter({
    DateTime? startDate,
    DateTime? endDate,
    int? categoryId,
    int? accountId,
    String? type,
  }) async {
    final q = <String, String>{
      'limit': '200',
      if (type != null) 'type': type,
      if (categoryId != null) 'categoryId': categoryId.toString(),
      if (accountId != null) 'accountId': accountId.toString(),
      if (startDate != null)
        'startDate': startDate.toUtc().toIso8601String(),
      if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
    };
    final res = await _api.get('/api/transactions', q: q);
    final list = (res['data']['transactions'] as List)
        .map((e) => _mapTxWithDetails(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<List<TransactionWithDetails>> getTransactionsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    return watchTransactionsWithFilter(startDate: start, endDate: end);
  }

  Future<Transaction> createTransaction({
    required int amount,
    required String type,
    required DateTime transactionDate,
    String description = '',
    required int accountId,
    required int categoryId,
    int? transferAccountId,
    int? eventId,
    int? memberId,
    String? proofImage,
  }) async {
    final res = await _api.post('/api/transactions', body: {
      'amount': amount,
      'type': type,
      'transactionDate': transactionDate.toUtc().toIso8601String(),
      'description': description,
      'accountId': accountId,
      'categoryId': categoryId,
      if (transferAccountId != null) 'transferAccountId': transferAccountId,
      if (eventId != null) 'eventId': eventId,
      if (memberId != null) 'memberId': memberId,
      'proofImage': null, // upload gambar belum didukung; selalu null
    });
    return _mapTransaction(res['data']['transaction'] as Map<String, dynamic>);
  }

  Future<void> updateTransaction({
    required int id,
    required int amount,
    required String type,
    required DateTime transactionDate,
    String description = '',
    required int accountId,
    required int categoryId,
    int? transferAccountId,
    int? eventId,
    int? memberId,
  }) async {
    await _api.patch('/api/transactions/$id', body: {
      'amount': amount,
      'type': type,
      'transactionDate': transactionDate.toUtc().toIso8601String(),
      'description': description,
      'accountId': accountId,
      'categoryId': categoryId,
      if (transferAccountId != null) 'transferAccountId': transferAccountId,
      if (eventId != null) 'eventId': eventId,
      if (memberId != null) 'memberId': memberId,
      'proofImage': null,
    });
  }

  Future<void> deleteTransaction(int id) async {
    await _api.delete('/api/transactions/$id');
  }

  // ============ Expense Breakdown (chart) ============

  Future<List<CategoryExpense>> watchExpenseBreakdown({
    DateTime? startDate,
    DateTime? endDate,
    bool allHistory = false,
  }) async {
    final res = await _api.get('/api/dashboard/by-category', q: {
      'type': 'Expense',
      if (allHistory) 'allHistory': 'true',
      if (startDate != null) 'startDate': startDate.toUtc().toIso8601String(),
      if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
    });
    final list = (res['data']['breakdown'] as List)
        .map((e) => CategoryExpense(
              categoryName: (e as Map<String, dynamic>)['category'] as String,
              totalAmount: (e['total'] as num).toInt(),
            ))
        .toList();
    return list;
  }

  // ============ Cash Periods & Logs ============

  Future<List<CashPeriod>> watchCashPeriods() async {
    final res = await _api.get('/api/cash/periods');
    final list = (res['data']['periods'] as List)
        .map((e) => _mapCashPeriod(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<CashPeriod> createCashPeriod({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    String status = 'Active',
  }) async {
    final res = await _api.post('/api/cash/periods', body: {
      'name': name,
      'startDate': startDate.toUtc().toIso8601String(),
      'endDate': endDate.toUtc().toIso8601String(),
      'status': status,
    });
    return _mapCashPeriod(res['data']['period'] as Map<String, dynamic>);
  }

  Future<void> updateCashPeriod({
    required int id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    await _api.patch('/api/cash/periods/$id', body: {
      if (name != null) 'name': name,
      if (startDate != null) 'startDate': startDate.toUtc().toIso8601String(),
      if (endDate != null) 'endDate': endDate.toUtc().toIso8601String(),
      if (status != null) 'status': status,
    });
  }

  Future<void> deleteCashPeriod(int id) async {
    await _api.delete('/api/cash/periods/$id');
  }

  Future<List<CashLog>> watchCashLogs() async {
    final res = await _api.get('/api/cash/logs');
    final list = (res['data']['cashLogs'] as List)
        .map((e) => _mapCashLog(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<List<CashLog>> watchCashLogsByPeriod(int periodId) async {
    final res = await _api.get('/api/cash/logs', q: {'periodId': periodId.toString()});
    final list = (res['data']['cashLogs'] as List)
        .map((e) => _mapCashLog(e as Map<String, dynamic>))
        .toList();
    return list;
  }

  Future<int> watchCollectedCashForPeriod(int periodId) async {
    final res = await _api.get('/api/cash/periods/$periodId/checklist');
    return (res['data']['summary']['totalCollected'] as num).toInt();
  }

  /// Checklist lengkap per periode (anggota + status bayar).
  Future<CashChecklist> getChecklist(int periodId) async {
    final res = await _api.get('/api/cash/periods/$periodId/checklist');
    final d = res['data'] as Map<String, dynamic>;
    final period = _mapCashPeriod(d['period'] as Map<String, dynamic>);
    final items = (d['checklist'] as List)
        .map((e) {
          final m = e as Map<String, dynamic>;
          return CashChecklistItem(
            memberId: (m['memberId'] as num).toInt(),
            memberName: (m['memberName'] ?? '') as String,
            phoneNumber: (m['phoneNumber'] as String?) ?? '',
            paid: m['paid'] as bool,
            amount: (m['amount'] as num?)?.toInt() ?? 0,
            transactionId: (m['transactionId'] as num?)?.toInt(),
            cashLogId: (m['cashLogId'] as num?)?.toInt(),
            paidAt: _parseDate(m['paidAt']),
          );
        })
        .toList();
    final s = d['summary'] as Map<String, dynamic>;
    return CashChecklist(
      period: period,
      items: items,
      totalMembers: (s['totalMembers'] as num).toInt(),
      paidCount: (s['paidCount'] as num).toInt(),
      unpaidCount: (s['unpaidCount'] as num).toInt(),
      totalCollected: (s['totalCollected'] as num).toInt(),
    );
  }

  Future<int> getOrInsertCashCategory() async {
    final cats = await watchCategories();
    final existing = cats.firstWhere(
      (c) => c.name == 'Uang Kas',
      orElse: () => Category(id: 0, name: '', type: '', iconKey: 'default'),
    );
    if (existing.id != 0) return existing.id;
    final created = await createCategory(name: 'Uang Kas', type: 'Income');
    return created.id;
  }

  /// Anggota membayar kas: POST /api/cash/pay.
  Future<void> payMemberCash({
    required int memberId,
    required String memberName,
    String? periodLabel,
    int? periodId,
    required int amount,
    required int accountId,
  }) async {
    final categoryId = await getOrInsertCashCategory();
    String label = periodLabel ?? 'Periode';
    if (periodId != null && periodLabel == null) {
      // label dari period name tidak wajib; backend pakai periodId
    }
    await _api.post('/api/cash/pay', body: {
      'memberId': memberId,
      'periodId': periodId,
      'amount': amount,
      'accountId': accountId,
      'categoryId': categoryId,
      'description': 'Kas $label - $memberName',
    });
  }

  /// Batalkan pembayaran kas: DELETE /api/cash/logs/:id (reverse saldo).
  Future<void> voidMemberCash({
    required int memberId,
    String? periodLabel,
    int? periodId,
  }) async {
    // Cari cashLog untuk member+period
    final res = await _api.get('/api/cash/logs', q: {
      'periodId': periodId?.toString() ?? '',
      'memberId': memberId.toString(),
    });
    final logs = (res['data']['cashLogs'] as List);
    if (logs.isEmpty) return;
    final log = logs.first as Map<String, dynamic>;
    await _api.delete('/api/cash/logs/${log['id']}');
  }
}
