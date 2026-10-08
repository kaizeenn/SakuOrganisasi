import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/dashboard_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import '../utils/icon_helper.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'account_detail_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final expenseAsync = ref.watch(expenseBreakdownProvider);
    final accountsAsync = ref.watch(accountsProvider);
    final p = context.palette;

    final fmt = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final hour = DateTime.now().hour;
    final greeting = hour < 11
        ? 'Selamat pagi'
        : hour < 15
        ? 'Selamat siang'
        : hour < 19
        ? 'Selamat sore'
        : 'Selamat malam';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardSummaryProvider);
            ref.invalidate(expenseBreakdownProvider);
            ref.invalidate(accountsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              // Top bar
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: context.texts.bodySmall?.copyWith(
                            color: p.textMuted,
                          ),
                        ),
                        Text(
                          'Ringkasan Keuangan',
                          style: context.texts.headlineSmall,
                        ),
                      ],
                    ),
                  ),
                  _IconAction(
                    icon: Icons.ios_share_rounded,
                    tooltip: 'Laporan',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportScreen()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _IconAction(
                    icon: Icons.settings_outlined,
                    tooltip: 'Pengaturan',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Hero balance
              summaryAsync.when(
                data: (s) => HeroPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.account_balance_wallet_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Total Saldo',
                            style: context.texts.titleSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          fmt.format(s.totalBalance),
                          style: context.texts.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _HeroStat(
                              label: 'Pemasukan',
                              value: fmt.format(s.totalIncome),
                              icon: Icons.south_west_rounded,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 34,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          Expanded(
                            child: _HeroStat(
                              label: 'Pengeluaran',
                              value: fmt.format(s.totalExpense),
                              icon: Icons.north_east_rounded,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fade(duration: 450.ms).slideY(
                  begin: 0.08,
                  end: 0,
                  duration: 500.ms,
                  curve: Curves.easeOutCubic,
                ),
                loading: () => const _LoadingCard(height: 190),
                error: (e, _) => _ErrorCard(message: '$e'),
              ),

              const SizedBox(height: 26),

              // Expense chart
              const SectionHeader(
                title: 'Detail Pengeluaran',
                subtitle: 'Distribusi per kategori',
              ),
              AppCard(
                padding: const EdgeInsets.all(18),
                child: expenseAsync.when(
                  data: (expenses) {
                    if (expenses.isEmpty) {
                      return const SizedBox(
                        height: 140,
                        child: Center(
                          child: Text('Belum ada data pengeluaran.'),
                        ),
                      );
                    }
                    final total = expenses.fold<int>(
                      0,
                      (sum, item) => sum + item.totalAmount,
                    );
                    final colors = _chartColors(p);

                    return Column(
                      children: [
                        SizedBox(
                          height: 190,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 3,
                                  centerSpaceRadius: 58,
                                  startDegreeOffset: -90,
                                  sections: List.generate(expenses.length, (i) {
                                    final e = expenses[i];
                                    final pct = total == 0
                                        ? 0
                                        : (e.totalAmount / total * 100);
                                    return PieChartSectionData(
                                      color: colors[i % colors.length],
                                      value: e.totalAmount.toDouble(),
                                      title: pct >= 8
                                          ? '${pct.toStringAsFixed(0)}%'
                                          : '',
                                      radius: 34,
                                      titleStyle: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    );
                                  }),
                                ),
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeOutCubic,
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Total',
                                    style: context.texts.bodySmall?.copyWith(
                                      color: p.textMuted,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 106,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        fmt.format(total),
                                        style: context.texts.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        ...List.generate(expenses.length, (i) {
                          final e = expenses[i];
                          final pct = total == 0
                              ? 0.0
                              : e.totalAmount / total * 100;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: colors[i % colors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    e.categoryName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.texts.bodyMedium,
                                  ),
                                ),
                                Text(
                                  '${pct.toStringAsFixed(0)}%',
                                  style: context.texts.labelSmall?.copyWith(
                                    color: p.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  fmt.format(e.totalAmount),
                                  style: context.texts.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                  loading: () => const _LoadingCard(height: 190),
                  error: (e, _) => _ErrorCard(message: '$e'),
                ),
              ).animate().fade(delay: 120.ms, duration: 450.ms),

              const SizedBox(height: 26),

              // Accounts
              SectionHeader(
                title: 'Daftar Akun',
                subtitle: 'Saldo per rekening & dompet',
                action: accountsAsync.maybeWhen(
                  data: (a) => Text(
                    '${a.length} akun',
                    style: context.texts.labelSmall?.copyWith(
                      color: p.textMuted,
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ),
              accountsAsync.when(
                data: (accounts) {
                  if (accounts.isEmpty) {
                    return AppCard(
                      child: EmptyState(
                        icon: Icons.account_balance_wallet_outlined,
                        title: 'Belum ada akun',
                        message: 'Tambahkan rekening atau dompet dulu.',
                      ),
                    );
                  }
                  return SizedBox(
                    height: 132,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(right: 4),
                      itemCount: accounts.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 14),
                      itemBuilder: (context, index) {
                        final account = accounts[index];
                        final tint = _chartColors(p)[index % 6];
                        return AppCard(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.all(16),
                          radius: AppRadius.lg,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AccountDetailScreen(account: account),
                            ),
                          ),
                          child: SizedBox(
                            width: 158,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(9),
                                      decoration: BoxDecoration(
                                        color: tint.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: Icon(
                                        IconHelper.getIcon(account.iconKey),
                                        color: tint,
                                        size: 18,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      account.type,
                                      style: context.texts.labelSmall?.copyWith(
                                        color: p.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  account.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.texts.titleSmall,
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    fmt.format(account.currentBalance),
                                    style: context.texts.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: p.brand,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .fade(delay: (200 + index * 70).ms, duration: 400.ms)
                            .slideX(
                              begin: 0.1,
                              end: 0,
                              delay: (200 + index * 70).ms,
                              duration: 400.ms,
                            );
                      },
                    ),
                  );
                },
                loading: () => const _LoadingCard(height: 132),
                error: (e, _) => _ErrorCard(message: '$e'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static List<Color> _chartColors(AppPalette p) => [
    p.brand,
    p.accent,
    p.income,
    p.transfer,
    const Color(0xFFEC4899),
    const Color(0xFF8B5CF6),
    const Color(0xFF14B8A6),
  ];
}

class _HeroStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.85)),
            const SizedBox(width: 5),
            Text(
              label,
              style: context.texts.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: context.texts.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: p.border),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, size: 19, color: p.textMuted),
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final double height;
  const _LoadingCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Icon(Icons.error_outline, color: context.palette.expense),
          const SizedBox(width: 10),
          Expanded(child: Text('Terjadi kesalahan: $message')),
        ],
      ),
    );
  }
}
