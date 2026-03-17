import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../repositories/transaction_repository.dart';
import '../providers/dashboard_providers.dart';
import '../screens/add_transaction_screen.dart';

class TransactionItemCard extends ConsumerWidget {
  final TransactionWithDetails item;
  final int? perspectiveAccountId;

  const TransactionItemCard({
    super.key,
    required this.item,
    this.perspectiveAccountId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final textColor = Theme.of(context).colorScheme.onSurface;
    final isTransfer = item.transaction.type == 'Transfer';
    final isIncome = item.transaction.type == 'Income';
    final isIncomingTransfer =
      perspectiveAccountId != null && item.destinationAccount?.id == perspectiveAccountId;
    final transactionColor = isTransfer
      ? isIncomingTransfer
          ? Colors.green
          : perspectiveAccountId != null
          ? Colors.red
          : Colors.blue
      : isIncome
      ? Colors.green
      : Colors.red;
    final amountText = isTransfer && perspectiveAccountId != null
      ? '${isIncomingTransfer ? '+' : '-'}${currencyFormatter.format(item.transaction.amount)}'
      : currencyFormatter.format(item.transaction.amount);
    final title = item.transaction.description.isEmpty
      ? isTransfer
          ? 'Transfer Saldo'
          : item.category.name
      : item.transaction.description;
    final subtitle = isTransfer
      ? perspectiveAccountId != null
          ? isIncomingTransfer
            ? 'Dari ${item.account.name}'
            : 'Ke ${item.destinationAccount?.name ?? '-'}'
          : '${item.account.name} → ${item.destinationAccount?.name ?? '-'}'
      : '${item.category.name} • ${item.account.name}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: transactionColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTransfer
                  ? Icons.swap_horiz
                  : isIncome
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              color: transactionColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                if (item.transaction.proofImage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: const [
                        Icon(Icons.image, size: 12, color: Colors.blue),
                        SizedBox(width: 4),
                        Text(
                          'Ada Bukti',
                          style: TextStyle(fontSize: 10, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: TextStyle(
                  color: transactionColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onSelected: (value) async {
              if (value == 'view_proof') {
                if (item.transaction.proofImage != null) {
                  await showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.file(File(item.transaction.proofImage!)),
                        ],
                      ),
                    ),
                  );
                }
              } else if (value == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AddTransactionScreen(editTransaction: item),
                  ),
                );
              } else if (value == 'delete') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Hapus Transaksi?'),
                    content: const Text('Tindakan ini tidak dapat dibatalkan.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Hapus'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  final repo = ref.read(transactionRepositoryProvider);
                  await repo.deleteTransaction(item.transaction);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Transaksi Dihapus')),
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
                      Icon(Icons.image, size: 18),
                      SizedBox(width: 8),
                      Text('Lihat Bukti'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Hapus', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
