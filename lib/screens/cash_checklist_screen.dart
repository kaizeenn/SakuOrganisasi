import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../providers/dashboard_providers.dart';
import '../providers/member_providers.dart';
import '../database/database.dart';
import '../services/member_payment_checklist_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';
import 'checklist_detail_screen.dart';

final periodCollectedAmountProvider = FutureProvider.family<int, int>((ref, periodId) {
  final repo = ref.watch(transactionRepositoryProvider);
  return repo.watchCollectedCashForPeriod(periodId);
});

class CashChecklistScreen extends ConsumerStatefulWidget {
  const CashChecklistScreen({super.key});

  @override
  ConsumerState<CashChecklistScreen> createState() => _CashChecklistScreenState();
}

class _CashChecklistScreenState extends ConsumerState<CashChecklistScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kas & Anggota'),
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
              controller: _tabController,
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
                Tab(height: 40, text: 'Tagihan'),
                Tab(height: 40, text: 'Anggota'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_PeriodsTab(), _MembersTab()],
      ),
    );
  }
}

// ---------------------------------------------------------
// TAB 1: PERIOD LIST
// ---------------------------------------------------------
class _PeriodsTab extends ConsumerWidget {
  const _PeriodsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodsAsync = ref.watch(cashPeriodsProvider);
    final p = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePeriodDialog(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Periode'),
      ),
      body: periodsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => EmptyState(
          icon: Icons.error_outline,
          title: 'Gagal memuat',
          message: '$e',
        ),
        data: (periods) {
          if (periods.isEmpty) {
            return EmptyState(
              icon: Icons.event_note_outlined,
              title: 'Belum ada periode kas',
              message: 'Buat periode untuk mulai menagih iuran anggota.',
              actionLabel: 'Buat Periode',
              onAction: () => _showCreatePeriodDialog(context, ref),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            itemCount: periods.length,
            itemBuilder: (context, index) {
              final period = periods[index];
              final active = period.status == 'Active';
              final statusColor = active ? p.income : p.textMuted;
              final collectedAsync = ref.watch(
                periodCollectedAmountProvider(period.id),
              );
              final amountFormatter = NumberFormat.decimalPattern('id_ID');

              return AppCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChecklistDetailScreen(
                      periodId: period.id,
                      periodName: period.name,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(
                            Icons.calendar_month_rounded,
                            color: statusColor,
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(period.name, style: context.texts.titleSmall),
                              const SizedBox(height: 2),
                              Text(
                                '${DateFormat('dd MMM yyyy').format(period.startDate)} — ${DateFormat('dd MMM yyyy').format(period.endDate)}',
                                style: context.texts.bodySmall?.copyWith(
                                  color: p.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cetak checklist',
                          icon: Icon(Icons.print_rounded, size: 19, color: p.textMuted),
                          onPressed: () => _printChecklistForPeriod(context, ref, period),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        AppBadge(
                          text: active ? 'Aktif' : 'Selesai',
                          color: statusColor,
                        ),
                        const Spacer(),
                        collectedAsync.when(
                          data: (total) => Text(
                            'Terkumpul Rp ${amountFormatter.format(total)}',
                            style: context.texts.labelSmall?.copyWith(
                              color: p.brand,
                            ),
                          ),
                          loading: () => Text(
                            'Terkumpul ...',
                            style: context.texts.labelSmall?.copyWith(
                              color: p.textMuted,
                            ),
                          ),
                          error: (e, s) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fade(delay: (index * 60).ms).slideY(
                begin: 0.05,
                end: 0,
                delay: (index * 60).ms,
                duration: 340.ms,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _printChecklistForPeriod(
    BuildContext context,
    WidgetRef ref,
    CashPeriod period,
  ) async {
    try {
      final service = MemberPaymentChecklistService(ref.read(databaseProvider));
      final members = await service.getMemberPaymentStatus(period.id);
      if (members.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Belum ada anggota untuk dicetak.')),
          );
        }
        return;
      }
      final pdfBytes = await service.generatePaymentChecklist(period, members);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Checklist_Pembayaran_${period.name}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal print: $e')));
      }
    }
  }

  Future<void> _showCreatePeriodDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final now = DateTime.now();
    nameCtrl.text = DateFormat('MMMM yyyy', 'id_ID').format(now);
    final startDate = now;
    final endDate = now.add(const Duration(days: 30));
    final p = context.palette;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buat Periode Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Periode',
                prefixIcon: Icon(Icons.event_note_rounded),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _DateChip(
                    label: 'Mulai',
                    date: startDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateChip(
                    label: 'Selesai',
                    date: endDate,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.brand,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final repo = ref.read(transactionRepositoryProvider);
              await repo.createCashPeriod(
                name: nameCtrl.text,
                startDate: startDate,
                endDate: endDate,
                status: 'Active',
              );
              invalidateAllData(ref);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final DateTime date;
  const _DateChip({required this.label, required this.date});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.texts.labelSmall?.copyWith(color: p.textMuted)),
          const SizedBox(height: 2),
          Text(
            DateFormat('dd MMM yy').format(date),
            style: context.texts.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// TAB 2: MEMBER LIST
// ---------------------------------------------------------
class _MembersTab extends ConsumerWidget {
  const _MembersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider);
    final p = context.palette;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMemberDialog(context, ref),
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => EmptyState(
          icon: Icons.error_outline,
          title: 'Gagal memuat',
          message: '$e',
        ),
        data: (members) {
          if (members.isEmpty) {
            return EmptyState(
              icon: Icons.groups_outlined,
              title: 'Belum ada anggota',
              message: 'Tambahkan anggota untuk mulai menagih kas.',
              actionLabel: 'Tambah Anggota',
              onAction: () => _showMemberDialog(context, ref),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final colors = [
                p.brand,
                p.accent,
                p.income,
                p.transfer,
              ];
              final c = colors[index % colors.length];
              return AppCard(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                onTap: () => _showMemberDialog(context, ref, member: member),
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
                    IconButton(
                      icon: Icon(Icons.edit_outlined, size: 18, color: p.accent),
                      onPressed: () =>
                          _showMemberDialog(context, ref, member: member),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: p.expense,
                      ),
                      onPressed: () => _deleteMember(context, ref, member),
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
    );
  }

  Future<void> _showMemberDialog(
    BuildContext context,
    WidgetRef ref, {
    Member? member,
  }) async {
    final nameCtrl = TextEditingController(text: member?.name ?? '');
    final phoneCtrl = TextEditingController(text: member?.phoneNumber ?? '');
    final p = context.palette;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(member == null ? 'Tambah Anggota' : 'Edit Anggota'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Anggota',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'No. HP (opsional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.brand,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () async {
              if (nameCtrl.text.isEmpty) return;
              final repo = ref.read(transactionRepositoryProvider);
              if (member == null) {
                await repo.createMember(
                  name: nameCtrl.text,
                  phoneNumber: phoneCtrl.text,
                );
              } else {
                await repo.updateMember(member.id, nameCtrl.text);
              }
              ref.invalidate(membersProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _deleteMember(BuildContext context, WidgetRef ref, Member member) {
    final p = context.palette;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Anggota?'),
        content: Text(
          'Hapus ${member.name}? Data kas terkait mungkin ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.expense,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () async {
              await ref.read(transactionRepositoryProvider).deleteMember(member.id);
              ref.invalidate(membersProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}
