import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'dashboard_providers.dart';

// Provider for Members List (API-backed)
final membersProvider = FutureProvider<List<Member>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.watchMembers();
});

// Provider for Cash Logs (API-backed)
final cashLogsProvider = FutureProvider<List<CashLog>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.watchCashLogs();
});
