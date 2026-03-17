import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../providers/member_providers.dart';
import '../providers/dashboard_providers.dart';

class ChecklistDetailScreen extends ConsumerWidget {
  final int periodId;
  final String periodName;

  const ChecklistDetailScreen({
    super.key,
    required this.periodId,
    required this.periodName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Members
    final membersAsync = ref.watch(membersProvider);
    // 2. Repo for actions
    final repo = ref.watch(transactionRepositoryProvider);
    // 3. Watch Logs for this Period
    final logsStream = repo.watchCashLogsByPeriod(periodId);

    return Scaffold(
      appBar: AppBar(title: Text(periodName)),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (members) {
          if (members.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada anggota. Silakan tambah di "Kelola Anggota".',
              ),
            );
          }

          return StreamBuilder<List<CashLog>>(
            stream: logsStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final logs = snapshot.data!;

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: members.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final member = members[index];
                  // Is Paid?
                  final log = logs.firstWhere(
                    (l) => l.memberId == member.id,
                    orElse: () => CashLog(
                      id: -1,
                      memberId: -1,
                      transactionId: -1,
                      periodLabel: null,
                      periodId: -1,
                    ),
                  );
                  final isPaid = log.id != -1;

                  return CheckboxListTile(
                    title: Text(
                      member.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      isPaid ? 'LUNAS' : 'Belum Lunas',
                      style: TextStyle(
                        color: isPaid ? Colors.green : Colors.red,
                        fontWeight: isPaid
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    value: isPaid,
                    activeColor: Colors.green,
                    secondary: CircleAvatar(
                      backgroundColor: isPaid
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      child: Icon(
                        isPaid ? Icons.check : Icons.person,
                        color: isPaid ? Colors.green : Colors.grey,
                      ),
                    ),
                    onChanged: (val) {
                      if (val == true) {
                        _showPaymentDialog(
                          context,
                          ref,
                          member,
                          periodId,
                          periodName,
                        );
                      } else {
                        // Void
                        _confirmVoid(context, ref, member, periodId);
                      }
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    Member member,
    int periodId,
    String periodName,
  ) {
    final amountController = TextEditingController(text: '10000'); // Default?
    // IMPROVEMENT: Use Formatter here too if desired, but user didn't explicitly ask for it here, only "AddTransactionScreen" and "CreatePeriodDialog"?
    // User Request 1: "Apply this formatter to the "Nominal/Amount" TextField. (Global Fix?)" -> "In AddTransactionScreen AND CreatePeriodDialog".
    // Wait, User Request logic: "REVAMP "KAS ANGGOTA"... Input: Use a Checkbox... Logic: Checking the box creates the Income Transaction".
    // Does checking the box show a dialog? "Logic: Checking the box creates the Income Transaction (as previously implemented)".
    // Previously implemented logic SHOWED A DIALOG.
    // So yes, I should show a dialog. And I should probably apply the formatter here too for consistency.

    int? selectedAccountId;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, _) {
            final accountsAsync = ref.watch(accountsProvider);

            return AlertDialog(
              title: Text('Bayar Kas: ${member.name}'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Jumlah Rp'),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Wajib' : null,
                    ),
                    const SizedBox(height: 16),
                    accountsAsync.when(
                      data: (accounts) {
                        if (accounts.isEmpty) {
                          return const Text('Buat akun dulu!');
                        }
                        selectedAccountId ??= accounts.first.id;
                        return DropdownButtonFormField<int>(
                          initialValue: selectedAccountId,
                          items: accounts
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text(a.name),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => selectedAccountId = v,
                          decoration: const InputDecoration(
                            labelText: 'Masuk ke Akun',
                          ),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => const Text('Error'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate() &&
                        selectedAccountId != null) {
                      final repo = ref.read(transactionRepositoryProvider);
                      // Parse amount (simple for now as I didn't add formatter import yet, keep it simple or strictly follow plan?
                      // Plan said "AddTransactionScreen and CreatePeriodDialog". Did NOT explicitly say "Checklist Detail".
                      // I will stick to simple parsing here to avoid over-engineering unless requested.
                      final amount =
                          int.tryParse(amountController.text) ?? 10000;
                      await repo.payMemberCash(
                        memberId: member.id,
                        memberName: member.name,
                        periodId: periodId,
                        amount: amount,
                        accountId: selectedAccountId!,
                      );
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Bayar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmVoid(
    BuildContext context,
    WidgetRef ref,
    Member member,
    int periodId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan?'),
        content: const Text('Hapus status lunas & transaksi saldo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final repo = ref.read(transactionRepositoryProvider);
              await repo.voidMemberCash(
                memberId: member.id,
                periodId: periodId,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }
}
