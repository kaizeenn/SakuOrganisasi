import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Events,
    Members,
    Transactions,
    CashLogs,
    CashPeriods,
  ],
)
class AppDatabase extends _$AppDatabase {
  static const _transferCategoryName = 'Transfer Antar Rekening';

  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(accounts, accounts.iconKey);
          await m.addColumn(categories, categories.iconKey);
        }
        if (from < 3) {
          await m.addColumn(transactions, transactions.proofImage);
        }
        if (from < 4) {
          await m.createTable(cashPeriods);
          await m.addColumn(cashLogs, cashLogs.periodId);
        }
        if (from < 5) {
          await m.addColumn(transactions, transactions.transferAccountId);
        }
      },
      beforeOpen: (details) async {
        // Seeding Data Logic
        if (details.wasCreated) {
          // Check if accounts are empty (redundant if new, but safe)
          // We can just act on 'wasCreated' which means it's a fresh DB

          // Seed Accounts
          await batch((batch) {
            batch.insertAll(accounts, [
              AccountsCompanion.insert(
                name: 'Tunai (Dompet)',
                type: 'Cash',
                initialBalance: 0,
                currentBalance: 0,
              ),
              AccountsCompanion.insert(
                name: 'BCA',
                type: 'Bank',
                initialBalance: 0,
                currentBalance: 0,
              ),
              AccountsCompanion.insert(
                name: 'Gopay',
                type: 'E-Wallet',
                initialBalance: 0,
                currentBalance: 0,
              ),
            ]);

            // Seed Categories
            batch.insertAll(categories, [
              CategoriesCompanion.insert(name: 'Makan', type: 'Expense'),
              CategoriesCompanion.insert(name: 'Transport', type: 'Expense'),
              CategoriesCompanion.insert(name: 'Gaji', type: 'Income'),
              CategoriesCompanion.insert(
                name: 'Kas Organisasi',
                type: 'Income',
              ),
              CategoriesCompanion.insert(
                name: _transferCategoryName,
                type: 'Transfer',
              ),
            ]);
          });
        } else {
          await ensureTransferCategoryExists();
        }
      },
    );
  }

  Future<void> ensureTransferCategoryExists() async {
    final existing = await (select(categories)..where(
      (tbl) =>
          tbl.name.equals(_transferCategoryName) & tbl.type.equals('Transfer'),
    )).getSingleOrNull();

    if (existing != null) return;

    await into(categories).insert(
      CategoriesCompanion.insert(
        name: _transferCategoryName,
        type: 'Transfer',
      ),
    );
  }

  // --- BACKUP & RESTORE METHODS ---

  Future<Map<String, List<Map<String, dynamic>>>> exportAllData() async {
    final allAccounts = await select(accounts).get();
    final allCategories = await select(categories).get();
    final allEvents = await select(events).get();
    final allMembers = await select(members).get();
    final allTransactions = await select(transactions).get();
    final allCashLogs = await select(cashLogs).get();
    final allCashPeriods = await select(cashPeriods).get();

    return {
      'accounts': allAccounts.map((e) => e.toJson()).toList(),
      'categories': allCategories.map((e) => e.toJson()).toList(),
      'events': allEvents.map((e) => e.toJson()).toList(),
      'members': allMembers.map((e) => e.toJson()).toList(),
      'transactions': allTransactions.map((e) => e.toJson()).toList(),
      'cashLogs': allCashLogs.map((e) => e.toJson()).toList(),
      'cashPeriods': allCashPeriods.map((e) => e.toJson()).toList(),
    };
  }

  Future<void> restoreData(Map<String, dynamic> data) async {
    await transaction(() async {
      final accountsData = ((data['accounts'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
      final categoriesData = ((data['categories'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
      final eventsData = ((data['events'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
      final membersData = ((data['members'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
      final cashPeriodsData = ((data['cashPeriods'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
      final transactionsData = ((data['transactions'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
      final cashLogsData = ((data['cashLogs'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

      // 1. DELETE ALL (Order matters: Child first)
      await delete(cashLogs).go();
      await delete(transactions).go();
      // Parents can be deleted now
      await delete(events).go();
      await delete(members).go();
      await delete(accounts).go();
      await delete(categories).go();
      await delete(cashPeriods).go();

      // 2. INSERT ALL (Order matters: Parent first)
      if (accountsData.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            accounts,
            accountsData.map(
              (e) => AccountsCompanion.insert(
                id: Value(e['id'] as int),
                name: e['name'] as String,
                type: e['type'] as String,
                initialBalance: e['initialBalance'] as int,
                currentBalance: e['currentBalance'] as int,
                iconKey: Value(e['iconKey'] as String? ?? 'default'),
              ),
            ),
          );
        });
      }

      if (categoriesData.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            categories,
            categoriesData.map(
              (e) => CategoriesCompanion.insert(
                id: Value(e['id'] as int),
                name: e['name'] as String,
                type: e['type'] as String,
                iconKey: Value(e['iconKey'] as String? ?? 'default'),
              ),
            ),
          );
        });
      }

      await ensureTransferCategoryExists();

      if (eventsData.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            events,
            eventsData.map(
              (e) => EventsCompanion.insert(
                id: Value(e['id'] as int),
                name: e['name'] as String,
                budgetLimit: e['budgetLimit'] as int,
                startDate: DateTime.fromMillisecondsSinceEpoch(
                  e['startDate'] as int,
                ),
                endDate: Value(
                  e['endDate'] != null
                      ? DateTime.fromMillisecondsSinceEpoch(
                          e['endDate'] as int,
                        )
                      : null,
                ),
                status: e['status'] as String,
              ),
            ),
          );
        });
      }

      if (membersData.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            members,
            membersData.map(
              (e) => MembersCompanion.insert(
                id: Value(e['id'] as int),
                name: e['name'] as String,
                phoneNumber: e['phoneNumber'] as String? ?? '',
              ),
            ),
          );
        });
      }

      if (cashPeriodsData.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            cashPeriods,
            cashPeriodsData.map(
              (e) => CashPeriodsCompanion.insert(
                id: Value(e['id'] as int),
                name: e['name'] as String,
                startDate: DateTime.fromMillisecondsSinceEpoch(
                  e['startDate'] as int,
                ),
                endDate: DateTime.fromMillisecondsSinceEpoch(
                  e['endDate'] as int,
                ),
                status: Value(e['status'] as String? ?? 'Active'),
                createdAt: Value(
                  e['createdAt'] != null
                      ? DateTime.fromMillisecondsSinceEpoch(
                          e['createdAt'] as int,
                        )
                      : DateTime.now(),
                ),
              ),
            ),
          );
        });
      }

      if (transactionsData.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            transactions,
            transactionsData.map((e) {
              return TransactionsCompanion.insert(
                id: Value(e['id'] as int),
                amount: e['amount'] as int,
                type: e['type'] as String,
                transactionDate: DateTime.fromMillisecondsSinceEpoch(
                  e['transactionDate'] as int,
                ),
                description: e['description'] as String,
                accountId: e['accountId'] as int,
                transferAccountId: Value(e['transferAccountId'] as int?),
                categoryId: e['categoryId'] as int,
                eventId: Value(e['eventId'] as int?),
                memberId: Value(e['memberId'] as int?),
                proofImage: Value(e['proofImage'] as String?),
              );
            }),
          );
        });
      }

      if (cashLogsData.isNotEmpty) {
        await batch((batch) {
          batch.insertAll(
            cashLogs,
            cashLogsData.map(
              (e) => CashLogsCompanion.insert(
                id: Value(e['id'] as int),
                memberId: e['memberId'] as int,
                transactionId: e['transactionId'] as int,
                periodLabel: Value(e['periodLabel'] as String?),
                periodId: Value(e['periodId'] as int?),
              ),
            ),
          );
        });
      }
    });
  }
}

LazyDatabase _openConnection() {
  // the LazyDatabase util lets us find the right location for the file async.
  return LazyDatabase(() async {
    // put the database file, called db.sqlite here, into the documents folder
    // for your app.
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
