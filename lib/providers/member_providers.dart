import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'dashboard_providers.dart';

// Provider for Members List
final membersProvider = StreamProvider<List<Member>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.watchMembers();
});

// Provider for Cash Logs (Checklist State)
final cashLogsProvider = StreamProvider<List<CashLog>>((ref) {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.watchCashLogs();
});
