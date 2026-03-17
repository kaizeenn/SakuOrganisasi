import 'package:drift/drift.dart';

// 1. Accounts Table
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // Bank, E-Wallet, Cash
  IntColumn get initialBalance => integer()();
  IntColumn get currentBalance => integer()();
  TextColumn get iconKey => text().withDefault(const Constant('default'))();
}

// 2. Categories Table
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // Income, Expense, Transfer
  TextColumn get iconKey => text().withDefault(const Constant('default'))();
}

// 3. Events Table (for "Proker")
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get budgetLimit => integer()();
  TextColumn get status => text()(); // Active, Finished
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
}

// 4. Members Table (for "Kas Anggota")
class Members extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phoneNumber => text()();
}

// 5. Transactions Table
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get amount => integer()();
  TextColumn get type => text()(); // Income, Expense, Transfer
  DateTimeColumn get transactionDate => dateTime()();
  TextColumn get description => text()();

  // Foreign Keys
  IntColumn get accountId => integer().references(Accounts, #id)();
  IntColumn get transferAccountId =>
      integer().nullable().references(Accounts, #id)();
  IntColumn get categoryId => integer().references(Categories, #id)();
  IntColumn get eventId => integer().nullable().references(Events, #id)();
  IntColumn get memberId => integer().nullable().references(Members, #id)();
  TextColumn get proofImage => text().nullable()();
}

// 6. CashLogs Table (Monthly cash payments)
class CashLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get memberId => integer().references(Members, #id)();
  IntColumn get transactionId => integer().references(Transactions, #id)();
  TextColumn get periodLabel =>
      text().nullable()(); // generic label (deprecated-ish)
  IntColumn get periodId => integer().nullable().references(CashPeriods, #id)();
}

// 7. CashPeriods Table (New for Flexible Cash)
class CashPeriods extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()(); // e.g. "Januari 2026", "Minggu 1", "Event X"
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get status =>
      text().withDefault(const Constant('Active'))(); // Active, Closed
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
