import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/dashboard_providers.dart';
import 'report_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final expenseAsync = ref.watch(expenseBreakdownProvider);
    final accountsAsync = ref.watch(accountsProvider);

    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      // backgroundColor handled by theme
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.blue),
            tooltip: 'Laporan PDF',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(
              Icons.settings,
              color: isDarkMode ? Colors.white70 : Colors.grey,
            ),
            tooltip: 'Pengaturan',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ringkasan Keuangan',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card 1: Total Saldo
            summaryAsync.when(
              data: (summary) =>
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Saldo',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currencyFormatter.format(summary.totalBalance),
                              style: TextStyle(
                                color: textColor,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet,
                            color: Colors.blue,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade().slideY(
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error: $err'),
            ),

            const SizedBox(height: 16),

            // Income / Expense Row
            summaryAsync.when(
              data: (summary) =>
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          label: 'Pemasukan',
                          value: summary.totalIncome,
                          icon: Icons.arrow_downward,
                          backgroundColor: isDarkMode
                              ? const Color(0xFF064E3B)
                              : const Color(
                                  0xFFDCFCE7,
                                ), // Dark Green vs Light Green
                          textColor: isDarkMode
                              ? const Color(0xFF34D399)
                              : const Color(0xFF166534),
                          formatter: currencyFormatter,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          label: 'Pengeluaran',
                          value: summary.totalExpense,
                          icon: Icons.arrow_upward,
                          backgroundColor: isDarkMode
                              ? const Color(0xFF7F1D1D)
                              : const Color(
                                  0xFFFEE2E2,
                                ), // Dark Red vs Light Red
                          textColor: isDarkMode
                              ? const Color(0xFFF87171)
                              : const Color(0xFF991B1B),
                          formatter: currencyFormatter,
                        ),
                      ),
                    ],
                  ).animate().fade().slideY(
                    delay: 100.ms,
                    duration: 400.ms,
                    curve: Curves.easeOut,
                  ),
              loading: () => const SizedBox.shrink(),
              error: (err, stack) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 24),

            // Pie Chart Section
            Text(
              'Detail Pengeluaran',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 250,
              padding: const EdgeInsets.all(16),
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
              child: expenseAsync.when(
                data: (expenses) {
                  if (expenses.isEmpty) {
                    return const Center(
                      child: Text('Belum ada data pengeluaran.'),
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 40,
                            sections: expenses.map((e) {
                              final index = expenses.indexOf(e);
                              final colors = [
                                Colors.blue,
                                Colors.red,
                                Colors.green,
                                Colors.orange,
                                Colors.purple,
                                Colors.teal,
                              ];
                              return PieChartSectionData(
                                color: colors[index % colors.length],
                                value: e.totalAmount.toDouble(),
                                title:
                                    '${(e.totalAmount / expenses.fold<int>(0, (sum, item) => sum + item.totalAmount) * 100).toStringAsFixed(0)}%',
                                radius: 60,
                                titleStyle: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Legend
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: expenses.map((e) {
                          final index = expenses.indexOf(e);
                          final colors = [
                            Colors.blue,
                            Colors.red,
                            Colors.green,
                            Colors.orange,
                            Colors.purple,
                            Colors.teal,
                          ];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  color: colors[index % colors.length],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  e.categoryName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textColor,
                                  ), // Dynamic Text
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ).animate().fade().slideY(
              delay: 200.ms,
              duration: 400.ms,
              curve: Curves.easeOut,
            ),
            const SizedBox(height: 24),

            // Account List Section
            Text(
              'Daftar Akun',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: accountsAsync.when(
                data: (accounts) {
                  if (accounts.isEmpty) return const Text('Belum ada akun.');
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: accounts.length,
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      return Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 12, bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue.withValues(
                                alpha: 0.1,
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet,
                                size: 18,
                                color: Colors.blue,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              account.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currencyFormatter.format(account.currentBalance),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fade().slideX(
                        delay: (300 + (index * 100)).ms,
                        duration: 400.ms,
                        curve: Curves.easeOut,
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required int value,
    required IconData icon,
    required Color backgroundColor,
    required Color textColor,
    required NumberFormat formatter,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatter.format(value),
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
