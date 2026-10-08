import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_providers.dart';
import '../providers/member_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

class MemberListScreen extends ConsumerWidget {
  const MemberListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider);
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Daftar Anggota')),
      body: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return EmptyState(
              icon: Icons.groups_outlined,
              title: 'Belum ada anggota',
              message: 'Tambahkan anggota organisasi.',
              actionLabel: 'Tambah Anggota',
              onAction: () => _showAddMemberDialog(context, ref),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final colors = [p.brand, p.accent, p.income, p.transfer];
              final c = colors[index % colors.length];
              return AppCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 21,
                      backgroundColor: c.withValues(alpha: 0.12),
                      child: Text(
                        member.name.isNotEmpty
                            ? member.name[0].toUpperCase()
                            : '?',
                        style: context.texts.titleSmall?.copyWith(color: c),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.name, style: context.texts.titleSmall),
                          if (member.phoneNumber.isNotEmpty)
                            Text(
                              member.phoneNumber,
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => EmptyState(
          icon: Icons.error_outline,
          title: 'Gagal memuat',
          message: '$err',
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMemberDialog(context, ref),
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final p = context.palette;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Anggota'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'No. HP (opsional)',
                  prefixIcon: Icon(Icons.phone_outlined),
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
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.brand,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final repo = ref.read(transactionRepositoryProvider);
                await repo.createMember(
                  name: nameController.text,
                  phoneNumber: phoneController.text,
                );
                ref.invalidate(membersProvider);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}