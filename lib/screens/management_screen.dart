import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'master_data_screen.dart';
import 'cash_checklist_screen.dart';

class ManagementScreen extends ConsumerWidget {
  const ManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            Text('Kelola', style: context.texts.headlineSmall),
            Text(
              'Atur data master & organisasi',
              style: context.texts.bodySmall?.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: 22),
            const SectionHeader(title: 'Keuangan'),
            _MenuTile(
              icon: Icons.account_balance_wallet_rounded,
              color: p.brand,
              title: 'Rekening & Dompet',
              subtitle: 'Kelola akun kas, bank, dan e-wallet',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MasterDataScreen(initialIndex: 0),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _MenuTile(
              icon: Icons.category_rounded,
              color: p.accent,
              title: 'Kategori Transaksi',
              subtitle: 'Atur kategori pemasukan & pengeluaran',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MasterDataScreen(initialIndex: 1),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Organisasi'),
            _MenuTile(
              icon: Icons.groups_rounded,
              color: p.income,
              title: 'Kas Anggota',
              subtitle: 'Periode tagihan, checklist, & anggota',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CashChecklistScreen()),
              ),
            ),
          ]
              .animate()
              .fade(duration: 380.ms)
              .slideY(begin: 0.04, end: 0, duration: 380.ms),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.texts.titleSmall?.copyWith(fontSize: 14.5)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: context.texts.bodySmall?.copyWith(color: p.textMuted),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.textMuted),
        ],
      ),
    );
  }
}
