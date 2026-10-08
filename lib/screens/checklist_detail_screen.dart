import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

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
    final p = context.palette;
    final checklistAsync = ref.watch(cashChecklistProvider(periodId));

    return Scaffold(
      appBar: AppBar(title: Text(periodName)),
      body: checklistAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => EmptyState(
          icon: Icons.error_outline,
          title: 'Gagal memuat',
          message: '$e',
        ),
        data: (checklist) {
          if (checklist.items.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              title: 'Belum ada anggota',
              message: 'Tambahkan anggota di tab "Anggota" terlebih dahulu.',
            );
          }
          final paidCount = checklist.paidCount;
          final total = checklist.totalMembers;
          final progress = total == 0 ? 0.0 : paidCount / total;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('Keterisian', style: context.texts.titleSmall),
                          const Spacer(),
                          AppBadge(
                            text: '$paidCount / $total lunas',
                            color: progress >= 1 ? p.income : p.brand,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 9,
                          backgroundColor: p.surfaceAlt,
                          valueColor: AlwaysStoppedAnimation(
                            progress >= 1 ? p.income : p.brand,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Terkumpul: Rp ${NumberFormat.decimalPattern('id_ID').format(checklist.totalCollected)}',
                        style: context.texts.labelSmall?.copyWith(
                          color: p.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  itemCount: checklist.items.length,
                  itemBuilder: (context, index) {
                    final item = checklist.items[index];
                    final isPaid = item.paid;
                    final colors = [p.brand, p.accent, p.income, p.transfer];
                    final c = colors[index % colors.length];

                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: c.withValues(alpha: 0.12),
                            child: Text(
                              item.memberName.isNotEmpty
                                  ? item.memberName[0].toUpperCase()
                                  : '?',
                              style: context.texts.titleSmall?.copyWith(
                                color: c,
                              ),
                            ),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.memberName,
                                  style: context.texts.titleSmall,
                                ),
                                const SizedBox(height: 3),
                                if (isPaid)
                                  AppBadge(
                                    text: 'Lunas',
                                    color: p.income,
                                    icon: Icons.check_rounded,
                                  )
                                else
                                  Text(
                                    'Belum lunas',
                                    style: context.texts.bodySmall?.copyWith(
                                      color: p.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isPaid)
                            IconButton(
                              tooltip: 'Batalkan',
                              icon: Icon(
                                Icons.undo_rounded,
                                color: p.expense,
                                size: 20,
                              ),
                              onPressed: () => _confirmVoid(
                                context,
                                ref,
                                item.memberId,
                                item.memberName,
                                periodId,
                              ),
                            )
                          else
                            FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 38),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                              ),
                              onPressed: () => _showPaymentDialog(
                                context,
                                ref,
                                item.memberId,
                                item.memberName,
                                periodId,
                                periodName,
                              ),
                              child: const Text('Bayar'),
                            ),
                        ],
                      ),
                    ).animate().fade(delay: (index * 40).ms).slideY(
                      begin: 0.05,
                      end: 0,
                      delay: (index * 40).ms,
                      duration: 300.ms,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showPaymentDialog(
    BuildContext context,
    WidgetRef ref,
    int memberId,
    String memberName,
    int periodId,
    String periodName,
  ) {
    final amountController = TextEditingController(text: '10000');
    int? selectedAccountId;
    final formKey = GlobalKey<FormState>();
    final p = context.palette;

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final accountsAsync = ref.watch(accountsProvider);
          return AlertDialog(
            title: Text('Bayar Kas — $memberName'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah',
                      prefixText: 'Rp ',
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 14),
                  accountsAsync.when(
                    data: (accounts) {
                      if (accounts.isEmpty) {
                        return const Text('Buat akun terlebih dahulu.');
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
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: p.brand,
                  minimumSize: const Size(0, 44),
                ),
                onPressed: () async {
                  if (formKey.currentState!.validate() &&
                      selectedAccountId != null) {
                    final repo = ref.read(transactionRepositoryProvider);
                    final amount =
                        int.tryParse(amountController.text) ?? 10000;
                    await repo.payMemberCash(
                      memberId: memberId,
                      memberName: memberName,
                      periodId: periodId,
                      amount: amount,
                      accountId: selectedAccountId!,
                    );
                    ref.invalidate(cashChecklistProvider(periodId));
                    invalidateAllData(ref);
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                child: const Text('Bayar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmVoid(
    BuildContext context,
    WidgetRef ref,
    int memberId,
    String memberName,
    int periodId,
  ) {
    final p = context.palette;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Pembayaran?'),
        content: const Text('Status lunas & transaksi saldo akan dihapus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tidak'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.expense,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () async {
              await ref.read(transactionRepositoryProvider).voidMemberCash(
                    memberId: memberId,
                    periodId: periodId,
                  );
              ref.invalidate(cashChecklistProvider(periodId));
              invalidateAllData(ref);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }
}
