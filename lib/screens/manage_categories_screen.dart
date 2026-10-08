import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dashboard_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Kelola Kategori')),
      body: ref.watch(categoriesProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => EmptyState(
          icon: Icons.error_outline,
          title: 'Gagal memuat',
          message: '$e',
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return EmptyState(
              icon: Icons.category_outlined,
              title: 'Belum ada kategori',
              message: 'Tambahkan kategori untuk mengelompokkan transaksi.',
              actionLabel: 'Tambah Kategori',
              onAction: () => _showAddDialog(context, ref),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final income = category.type == 'Income';
              final color = income ? p.income : p.expense;
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
                      child: Icon(
                        income
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(category.name, style: context.texts.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            income ? 'Pemasukan' : 'Pengeluaran',
                            style: context.texts.bodySmall?.copyWith(
                              color: p.textMuted,
                            ),
                          ),
                        ],
                      ),
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String type = 'Expense';
    final formKey = GlobalKey<FormState>();
    final p = context.palette;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Tambah Kategori'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Kategori',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: ['Income', 'Expense']
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e == 'Income' ? 'Pemasukan' : 'Pengeluaran',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => type = val!),
                  decoration: const InputDecoration(labelText: 'Tipe'),
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
                if (formKey.currentState!.validate()) {
                  final repo = ref.read(transactionRepositoryProvider);
                  await repo.createCategory(
                    name: nameController.text,
                    type: type,
                  );
                  invalidateAllData(ref);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
