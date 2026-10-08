import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_providers.dart';
import '../theme/app_theme.dart';
import '../utils/icon_helper.dart';
import '../widgets/ui_kit.dart';
import '../database/database.dart';
import 'account_detail_screen.dart';

class MasterDataScreen extends ConsumerWidget {
  final int initialIndex;

  const MasterDataScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kelola Data'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(999),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: p.shadow,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: p.brand,
                unselectedLabelColor: p.textMuted,
                tabs: const [
                  Tab(height: 40, text: 'Akun Keuangan'),
                  Tab(height: 40, text: 'Kategori'),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(children: [_AccountsTab(), _CategoriesTab()]),
      ),
    );
  }
}

// --- ACCOUNTS TAB ---
class _AccountsTab extends ConsumerWidget {
  const _AccountsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAccountDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Akun'),
      ),
      body: ref.watch(accountsProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => EmptyState(
          icon: Icons.error_outline,
          title: 'Gagal memuat',
          message: '$e',
        ),
        data: (accounts) {
          if (accounts.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Belum ada akun',
              message: 'Tambahkan rekening atau dompet pertama Anda.',
              actionLabel: 'Tambah Akun',
              onAction: () => _showAccountDialog(context, ref),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return AppCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AccountDetailScreen(account: account),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: p.brandSoft,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        IconHelper.getIcon(account.iconKey),
                        color: p.brand,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(account.name, style: context.texts.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            account.type,
                            style: context.texts.bodySmall?.copyWith(
                              color: p.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _MiniAction(
                      icon: Icons.edit_outlined,
                      color: p.accent,
                      onTap: () =>
                          _showAccountDialog(context, ref, account: account),
                    ),
                    const SizedBox(width: 6),
                    _MiniAction(
                      icon: Icons.delete_outline_rounded,
                      color: p.expense,
                      onTap: () => _deleteAccount(context, ref, account),
                    ),
                  ],
                ),
              ).animate().fade(delay: (index * 50).ms).slideY(
                begin: 0.05,
                end: 0,
                delay: (index * 50).ms,
                duration: 340.ms,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    Account account,
  ) async {
    final p = context.palette;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Akun'),
        content: Text(
          'Hapus "${account.name}"? Akun yang masih memiliki transaksi tidak bisa dihapus.',
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
      try {
        await ref.read(transactionRepositoryProvider).deleteAccount(account.id);
        invalidateAllData(ref);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Akun dihapus')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
        }
      }
    }
  }

  Future<void> _showAccountDialog(
    BuildContext context,
    WidgetRef ref, {
    Account? account,
  }) async {
    final isEdit = account != null;
    final nameCtrl = TextEditingController(text: account?.name ?? '');
    String selectedType = account?.type ?? 'Bank';
    final balanceCtrl = TextEditingController(
      text: (account?.currentBalance ?? 0).toString(),
    );
    String selectedIcon = account?.iconKey ?? 'default';
    final p = context.palette;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Akun' : 'Tambah Akun'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () async {
                      final icon = await _showIconPicker(context);
                      if (icon != null) setState(() => selectedIcon = icon);
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: p.brandSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        IconHelper.getIcon(selectedIcon),
                        size: 30,
                        color: p.brand,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ketuk untuk ganti ikon',
                    style: context.texts.labelSmall?.copyWith(
                      color: p.textMuted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Akun'),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Tipe'),
                    items: const [
                      DropdownMenuItem(value: 'Cash', child: Text('Tunai')),
                      DropdownMenuItem(value: 'Bank', child: Text('Bank')),
                      DropdownMenuItem(
                        value: 'E-Wallet',
                        child: Text('E-Wallet'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => selectedType = v);
                    },
                  ),
                  if (!isEdit) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: balanceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Saldo Awal',
                        prefixText: 'Rp ',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  final repo = ref.read(transactionRepositoryProvider);
                  if (isEdit) {
                    await repo.updateAccount(
                      id: account.id,
                      name: nameCtrl.text,
                      type: selectedType,
                      iconKey: selectedIcon,
                    );
                  } else {
                    await repo.createAccount(
                      name: nameCtrl.text,
                      type: selectedType,
                      initialBalance:
                          int.tryParse(balanceCtrl.text) ?? 0,
                      iconKey: selectedIcon,
                    );
                  }
                  invalidateAllData(ref);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- CATEGORIES TAB ---
class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Kategori'),
      ),
      body: ref.watch(categoriesProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => EmptyState(
          icon: Icons.error_outline,
          title: 'Gagal memuat',
          message: '$e',
        ),
        data: (categories) {
          final income = categories.where((c) => c.type == 'Income').toList();
          final expense = categories.where((c) => c.type == 'Expense').toList();

          if (categories.isEmpty) {
            return EmptyState(
              icon: Icons.category_outlined,
              title: 'Belum ada kategori',
              message: 'Tambahkan kategori pemasukan atau pengeluaran.',
              actionLabel: 'Tambah Kategori',
              onAction: () => _showCategoryDialog(context, ref),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            children: [
              if (income.isNotEmpty) ...[
                SectionHeader(
                  title: 'Pemasukan',
                  subtitle: '${income.length} kategori',
                ),
                ...income.map((c) => _tile(context, ref, c, p.income)),
              ],
              if (expense.isNotEmpty) ...[
                const SizedBox(height: 12),
                SectionHeader(
                  title: 'Pengeluaran',
                  subtitle: '${expense.length} kategori',
                ),
                ...expense.map((c) => _tile(context, ref, c, p.expense)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    Category category,
    Color color,
  ) {
    final p = context.palette;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      radius: AppRadius.md,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child:
                Icon(IconHelper.getIcon(category.iconKey), color: color, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(category.name, style: context.texts.titleSmall),
          ),
          _MiniAction(
            icon: Icons.edit_outlined,
            color: p.accent,
            onTap: () =>
                _showCategoryDialog(context, ref, category: category),
          ),
          const SizedBox(width: 6),
          _MiniAction(
            icon: Icons.delete_outline_rounded,
            color: p.expense,
            onTap: () => _deleteCategory(context, ref, category.id),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
    final p = context.palette;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Kategori?'),
        content: const Text(
          'Pastikan kategori ini tidak digunakan oleh transaksi aktif.',
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
      try {
        await ref.read(transactionRepositoryProvider).deleteCategory(id);
        invalidateAllData(ref);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Kategori dihapus')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
        }
      }
    }
  }

  Future<void> _showCategoryDialog(
    BuildContext context,
    WidgetRef ref, {
    Category? category,
  }) async {
    final isEdit = category != null;
    final nameCtrl = TextEditingController(text: category?.name ?? '');
    String selectedType = category?.type ?? 'Expense';
    String selectedIcon = category?.iconKey ?? 'default';
    final p = context.palette;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Kategori' : 'Tambah Kategori'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () async {
                      final icon = await _showIconPicker(context);
                      if (icon != null) setState(() => selectedIcon = icon);
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: p.brandSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        IconHelper.getIcon(selectedIcon),
                        size: 30,
                        color: p.brand,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ketuk untuk ganti ikon',
                    style: context.texts.labelSmall?.copyWith(
                      color: p.textMuted,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kategori',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Tipe'),
                    items: const [
                      DropdownMenuItem(
                        value: 'Income',
                        child: Text('Pemasukan'),
                      ),
                      DropdownMenuItem(
                        value: 'Expense',
                        child: Text('Pengeluaran'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => selectedType = v);
                    },
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
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;
                  final repo = ref.read(transactionRepositoryProvider);
                  if (isEdit) {
                    await repo.updateCategory(
                      id: category.id,
                      name: nameCtrl.text,
                      type: selectedType,
                      iconKey: selectedIcon,
                    );
                  } else {
                    await repo.createCategory(
                      name: nameCtrl.text,
                      type: selectedType,
                      iconKey: selectedIcon,
                    );
                  }
                  invalidateAllData(ref);
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MiniAction({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 17, color: color),
        ),
      ),
    );
  }
}

// --- ICON PICKER ---
Future<String?> _showIconPicker(BuildContext context) async {
  final p = context.palette;
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Pilih Ikon'),
      content: SizedBox(
        width: double.maxFinite,
        child: GridView.count(
          crossAxisCount: 5,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          shrinkWrap: true,
          children: IconHelper.iconMap.entries.map((entry) {
            return InkWell(
              onTap: () => Navigator.pop(context, entry.key),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(entry.value, color: p.brand, size: 20),
              ),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
      ],
    ),
  );
}
