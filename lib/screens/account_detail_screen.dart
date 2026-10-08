import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../providers/dashboard_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../widgets/transaction_item_card.dart';

class AccountDetailScreen extends ConsumerWidget {
  final Account account;

  const AccountDetailScreen({super.key, required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return Scaffold(
      appBar: AppBar(title: Text(account.name)),
      body: ref.watch(transactionsByAccountProvider(account.id)).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (transactions) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: HeroPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Saldo Saat Ini',
                                style: context.texts.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                              Text(
                                account.type,
                                style: context.texts.titleSmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          fmt.format(account.currentBalance),
                          style: context.texts.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fade().slideY(
                begin: -0.1,
                end: 0,
                duration: 380.ms,
              ),
            ),
            if (transactions.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Belum ada transaksi',
                  message: 'Transaksi pada akun ini akan tampil di sini.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                sliver: SliverList.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    return TransactionItemCard(
                      item: transactions[index],
                      perspectiveAccountId: account.id,
                    ).animate().fade(delay: (index * 30).ms).slideX(
                      begin: 0.05,
                      end: 0,
                      delay: (index * 30).ms,
                      duration: 300.ms,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
