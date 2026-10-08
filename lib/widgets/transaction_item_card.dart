import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../repositories/transaction_repository.dart';
import '../providers/dashboard_providers.dart';
import '../theme/app_theme.dart';
import '../screens/add_transaction_screen.dart';

class TransactionItemCard extends ConsumerWidget {
  final TransactionWithDetails item;
  final int? perspectiveAccountId;
  final bool dense;

  const TransactionItemCard({
    super.key,
    required this.item,
    this.perspectiveAccountId,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final isTransfer = item.transaction.type == 'Transfer';
    final isIncome = item.transaction.type == 'Income';
    final isIncomingTransfer =
        perspectiveAccountId != null &&
        item.destinationAccount?.id == perspectiveAccountId;

    final color = isTransfer
        ? (isIncomingTransfer
              ? p.income
              : perspectiveAccountId != null
              ? p.expense
              : p.transfer)
        : isIncome
        ? p.income
        : p.expense;

    final icon = isTransfer
        ? Icons.swap_horiz_rounded
        : isIncome
        ? Icons.south_west_rounded
        : Icons.north_east_rounded;

    final showSigned = isTransfer && perspectiveAccountId != null;
    final amountText =
        '${showSigned ? (isIncomingTransfer ? '+ ' : '- ') : (isIncome ? '+ ' : '- ')}${currencyFormatter.format(item.transaction.amount)}';

    final title = item.transaction.description.isEmpty
        ? (isTransfer ? 'Transfer Saldo' : item.category.name)
        : item.transaction.description;

    final subtitle = isTransfer
        ? (perspectiveAccountId != null
              ? (isIncomingTransfer
                    ? 'Dari ${item.account.name}'
                    : 'Ke ${item.destinationAccount?.name ?? '-'}')
              : '${item.account.name} → ${item.destinationAccount?.name ?? '-'}')
        : '${item.category.name} • ${item.account.name}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: p.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddTransactionScreen(editTransaction: item),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: dense ? 12 : 14,
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.texts.titleSmall?.copyWith(
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              subtitle,
                              style: context.texts.bodySmall?.copyWith(
                                color: p.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.transaction.proofImage != null) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.attach_file_rounded, size: 13, color: p.brand),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountText,
                      style: context.texts.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMM').format(item.transaction.transactionDate),
                      style: context.texts.labelSmall?.copyWith(
                        color: p.textMuted,
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: p.textMuted, size: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  onSelected: (value) async {
                    if (value == 'view_proof') {
                      if (item.transaction.proofImage != null) {
                        await showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            clipBehavior: Clip.antiAlias,
                            child: InteractiveViewer(
                              child: Image.file(
                                File(item.transaction.proofImage!),
                              ),
                            ),
                          ),
                        );
                      }
                    } else if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AddTransactionScreen(editTransaction: item),
                        ),
                      );
                    } else if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Hapus Transaksi?'),
                          content: const Text(
                            'Tindakan ini tidak dapat dibatalkan.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Batal'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: p.expense,
                                minimumSize: const Size(0, 44),
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Hapus'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        final repo = ref.read(transactionRepositoryProvider);
                        await repo.deleteTransaction(item.transaction.id);
                        invalidateAllData(ref);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Transaksi dihapus')),
                          );
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    if (item.transaction.proofImage != null)
                      const PopupMenuItem(
                        value: 'view_proof',
                        child: Row(
                          children: [
                            Icon(Icons.image_outlined, size: 18),
                            SizedBox(width: 10),
                            Text('Lihat Bukti'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          SizedBox(width: 10),
                          Text('Hapus', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
