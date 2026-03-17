import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../database/database.dart';
import '../providers/dashboard_providers.dart';
import '../utils/icon_helper.dart';
import '../screens/account_detail_screen.dart';

class MasterDataScreen extends ConsumerWidget {
  final int initialIndex;

  const MasterDataScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kelola Data'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Akun Keuangan', icon: Icon(Icons.wallet)),
              Tab(text: 'Kategori', icon: Icon(Icons.category)),
            ],
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
    final repo = ref.watch(transactionRepositoryProvider);

    return StreamBuilder<List<Account>>(
      stream: repo.watchAccounts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final accounts = snapshot.data!;

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAccountDialog(context, ref),
            label: const Text('Tambah Akun'),
            icon: const Icon(Icons.add),
          ),
          body: ListView.builder(
            itemCount: accounts.length,
            padding: const EdgeInsets.only(bottom: 80),
            itemBuilder: (context, index) {
              final account = accounts[index];
              return Card(
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AccountDetailScreen(account: account),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Icon(
                      IconHelper.getIcon(account.iconKey),
                      color: Colors.blue,
                    ),
                  ),
                  title: Text(account.name),
                  subtitle: Text(account.type),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () =>
                            _showAccountDialog(context, ref, account: account),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteAccount(
                          context,
                          ref,
                          account,
                          accounts,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    Account account,
    List<Account> allAccounts,
  ) async {
    final replacementCandidates = allAccounts
        .where((a) => a.id != account.id)
        .toList();

    if (replacementCandidates.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Minimal harus ada 1 akun lain sebagai pengganti.'),
          ),
        );
      }
      return;
    }

    int selectedReplacementId = replacementCandidates.first.id;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Hapus Akun & Pindah Transaksi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Semua histori transaksi dari akun "${account.name}" akan dipindah ke akun pengganti.',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: selectedReplacementId,
                decoration: const InputDecoration(
                  labelText: 'Akun Pengganti',
                  border: OutlineInputBorder(),
                ),
                items: replacementCandidates
                    .map(
                      (a) => DropdownMenuItem<int>(
                        value: a.id,
                        child: Text(a.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedReplacementId = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Pindah & Hapus'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        await ref
            .read(transactionRepositoryProvider)
            .deleteAccountWithReplacement(
              accountId: account.id,
              replacementAccountId: selectedReplacementId,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            const SnackBar(content: Text('Akun dihapus & transaksi dipindahkan')),
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
    final typeCtrl = TextEditingController(text: account?.type ?? 'Bank');
    final balanceCtrl = TextEditingController(
      text: (account?.currentBalance ?? 0).toString(),
    );
    String selectedIcon = account?.iconKey ?? 'default';

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
                  // Icon Picker Trigger
                  InkWell(
                    onTap: () async {
                      final icon = await _showIconPicker(context);
                      if (icon != null) {
                        setState(() => selectedIcon = icon);
                      }
                    },
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey.shade200,
                      child: Icon(IconHelper.getIcon(selectedIcon), size: 30),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pilih Ikon',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Akun',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tipe',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: typeCtrl.text,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(
                            value: 'Cash',
                            child: Text('Cash (Tunai)'),
                          ),
                          DropdownMenuItem(value: 'Bank', child: Text('Bank')),
                          DropdownMenuItem(
                            value: 'E-Wallet',
                            child: Text('E-Wallet'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => typeCtrl.text = v);
                        },
                      ),
                    ),
                  ),
                  if (!isEdit) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: balanceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Saldo Awal',
                        border: OutlineInputBorder(),
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
              ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.isEmpty) return;

                  final entry = AccountsCompanion(
                    name: drift.Value(nameCtrl.text),
                    type: drift.Value(typeCtrl.text),
                    iconKey: drift.Value(selectedIcon),
                    // Only update balance logic if needed, usually we don't edit Initial Balance for existing
                    initialBalance: isEdit
                        ? drift.Value.absent()
                        : drift.Value(int.tryParse(balanceCtrl.text) ?? 0),
                    currentBalance: isEdit
                        ? drift.Value.absent()
                        : drift.Value(int.tryParse(balanceCtrl.text) ?? 0),
                  );

                  final repo = ref.read(transactionRepositoryProvider);
                  if (isEdit) {
                    await repo.updateAccount(
                      entry.copyWith(id: drift.Value(account.id)),
                    );
                  } else {
                    await repo.createAccount(entry);
                  }
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
    final repo = ref.watch(transactionRepositoryProvider);

    return StreamBuilder<List<Category>>(
      stream: repo.watchCategories(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final categories = snapshot.data!;

        // Group by Type (Income/Expense)
        final income = categories.where((c) => c.type == 'Income').toList();
        final expense = categories.where((c) => c.type == 'Expense').toList();

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showCategoryDialog(context, ref),
            label: const Text('Tambah Kategori'),
            icon: const Icon(Icons.add),
            backgroundColor: Colors.orange,
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              if (income.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Pemasukan',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                ...income.map((c) => _buildTile(context, ref, c)),
              ],
              if (expense.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Pengeluaran',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
                ...expense.map((c) => _buildTile(context, ref, c)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTile(BuildContext context, WidgetRef ref, Category category) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: category.type == 'Income'
              ? Colors.green.shade100
              : Colors.red.shade100,
          child: Icon(
            IconHelper.getIcon(category.iconKey),
            color: category.type == 'Income' ? Colors.green : Colors.red,
          ),
        ),
        title: Text(category.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.orange),
              onPressed: () =>
                  _showCategoryDialog(context, ref, category: category),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteCategory(context, ref, category.id),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    int id,
  ) async {
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(transactionRepositoryProvider).deleteCategory(id);
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
    // Default to Expense for new categories unless specified
    String selectedType = category?.type ?? 'Expense';
    String selectedIcon = category?.iconKey ?? 'default';

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
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.grey.shade200,
                      child: Icon(IconHelper.getIcon(selectedIcon), size: 30),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pilih Ikon',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kategori',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tipe',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedType,
                        isDense: true,
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
                    ),
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
                  if (nameCtrl.text.isEmpty) return;

                  final entry = CategoriesCompanion(
                    name: drift.Value(nameCtrl.text),
                    type: drift.Value(selectedType),
                    iconKey: drift.Value(selectedIcon),
                  );

                  final repo = ref.read(transactionRepositoryProvider);
                  if (isEdit) {
                    await repo.updateCategory(
                      entry.copyWith(id: drift.Value(category.id)),
                    );
                  } else {
                    await repo.createCategory(entry);
                  }
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

// --- ICON PICKER DIALOG ---
Future<String?> _showIconPicker(BuildContext context) async {
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
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(entry.value, color: Colors.blueGrey),
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
