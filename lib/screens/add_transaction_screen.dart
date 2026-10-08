import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_providers.dart';
import '../repositories/transaction_repository.dart';
import '../theme/app_theme.dart';
import '../utils/currency_format.dart';
import '../widgets/ui_kit.dart';
import 'master_data_screen.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final TransactionWithDetails? editTransaction;

  const AddTransactionScreen({super.key, this.editTransaction});

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _amountController;
  late final TextEditingController _descController;

  String _type = 'Expense';
  int _amount = 0;
  String? _description;
  int? _selectedAccountId;
  int? _selectedTransferAccountId;
  int? _selectedCategoryId;
  int? _selectedEventId;
  DateTime _selectedDate = DateTime.now();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _descController = TextEditingController();

    if (widget.editTransaction != null) {
      final tx = widget.editTransaction!.transaction;
      _type = tx.type;
      _amount = tx.amount;
      _amountController.text = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(tx.amount);
      _description = tx.description;
      _descController.text = tx.description;
      _selectedAccountId = tx.accountId;
      _selectedTransferAccountId = tx.transferAccountId;
      _selectedCategoryId = tx.categoryId;
      _selectedEventId = tx.eventId;
      _selectedDate = tx.transactionDate;
      if (tx.proofImage != null) _imageFile = File(tx.proofImage!);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? photo = await _picker.pickImage(
      source: source,
      imageQuality: 50,
    );
    if (photo != null && mounted) {
      setState(() => _imageFile = File(photo.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editTransaction == null ? 'Tambah Transaksi' : 'Edit Transaksi',
        ),
        actions: [
          if (widget.editTransaction != null)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: p.expense),
              onPressed: _deleteTransaction,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type selector
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    _typeTab('Pemasukan', 'Income', p.income),
                    _typeTab('Pengeluaran', 'Expense', p.expense),
                    _typeTab('Transfer', 'Transfer', p.transfer),
                  ],
                ),
              ).animate().fade().slideY(begin: 0.1, end: 0, duration: 300.ms),
              const SizedBox(height: 24),

              // Amount
              const _FieldLabel('Jumlah'),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  RupiahInputFormatter(),
                ],
                style: context.texts.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  hintText: 'Rp 0',
                  prefixIcon: Icon(Icons.payments_rounded, color: p.brand),
                ),
                onChanged: (val) {
                  final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
                  _amount = int.tryParse(clean) ?? 0;
                },
                validator: (val) => _amount <= 0 ? 'Jumlah harus lebih dari 0' : null,
              ),
              const SizedBox(height: 20),

              // Source account
              _FieldLabel(_type == 'Transfer' ? 'Akun Sumber' : 'Akun'),
              accountsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (err, _) => Text(
                  'Error: $err',
                  style: TextStyle(color: p.expense),
                ),
                data: (accounts) {
                  if (accounts.isEmpty) {
                    return _buildEmptyState(
                      'Belum ada akun.',
                      'Buat Akun',
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MasterDataScreen(initialIndex: 0),
                        ),
                      ),
                    );
                  }
                  if (_selectedAccountId == null &&
                      widget.editTransaction == null) {
                    Future.microtask(() {
                      if (mounted) {
                        setState(() => _selectedAccountId = accounts.first.id);
                      }
                    });
                  }
                  return DropdownButtonFormField<int>(
                    initialValue: _selectedAccountId,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.account_balance_wallet_rounded),
                    ),
                    items: accounts
                        .map(
                          (acc) => DropdownMenuItem(
                            value: acc.id,
                            child: Text('${acc.name} (${acc.type})'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedAccountId = val),
                    validator: (val) => val == null ? 'Pilih akun' : null,
                  );
                },
              ),

              // Transfer destination
              if (_type == 'Transfer') ...[
                const SizedBox(height: 20),
                const _FieldLabel('Akun Tujuan'),
                accountsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (err, _) => Text('Error: $err'),
                  data: (accounts) {
                    final targets = accounts
                        .where((acc) => acc.id != _selectedAccountId)
                        .toList();

                    if (_selectedTransferAccountId != null &&
                        !targets.any((a) => a.id == _selectedTransferAccountId)) {
                      Future.microtask(() {
                        if (mounted) {
                          setState(
                            () => _selectedTransferAccountId =
                                targets.isEmpty ? null : targets.first.id,
                          );
                        }
                      });
                    }
                    if (_selectedTransferAccountId == null &&
                        targets.isNotEmpty &&
                        widget.editTransaction == null) {
                      Future.microtask(() {
                        if (mounted) {
                          setState(
                            () => _selectedTransferAccountId = targets.first.id,
                          );
                        }
                      });
                    }
                    if (targets.isEmpty) {
                      return _buildEmptyState(
                        'Tambahkan minimal 2 akun untuk transfer.',
                        'Kelola Akun',
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const MasterDataScreen(initialIndex: 0),
                          ),
                        ),
                      );
                    }
                    return DropdownButtonFormField<int>(
                      initialValue: _selectedTransferAccountId,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.arrow_forward_rounded),
                      ),
                      items: targets
                          .map(
                            (acc) => DropdownMenuItem(
                              value: acc.id,
                              child: Text('${acc.name} (${acc.type})'),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedTransferAccountId = val),
                      validator: (val) =>
                          val == null ? 'Pilih akun tujuan' : null,
                    );
                  },
                ),
              ],

              const SizedBox(height: 20),

              // Category
              if (_type != 'Transfer') ...[
                const _FieldLabel('Kategori'),
                categoriesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (err, _) => Text('Error: $err'),
                  data: (categories) {
                    final filtered = categories
                        .where((c) => c.type == _type)
                        .toList();
                    if (filtered.isEmpty) {
                      return _buildEmptyState(
                        'Belum ada kategori.',
                        'Buat Kategori',
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const MasterDataScreen(initialIndex: 1),
                          ),
                        ),
                      );
                    }
                    if (_selectedCategoryId != null &&
                        !filtered.any((c) => c.id == _selectedCategoryId)) {
                      Future.microtask(() {
                        if (mounted) {
                          setState(() => _selectedCategoryId = null);
                        }
                      });
                    }
                    return DropdownButtonFormField<int>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.category_rounded),
                      ),
                      items: filtered
                          .map(
                            (cat) => DropdownMenuItem(
                              value: cat.id,
                              child: Text(cat.name),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCategoryId = val),
                      validator: (val) => val == null ? 'Pilih kategori' : null,
                    );
                  },
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: p.transfer.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: p.transfer.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz_rounded, color: p.transfer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Transfer dicatat sebagai perpindahan saldo antar akun, tanpa mempengaruhi pemasukan/pengeluaran.',
                          style: context.texts.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Description
              const _FieldLabel('Catatan (opsional)'),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Iuran bulanan anggota',
                ),
                onChanged: (val) => _description = val,
              ),

              const SizedBox(height: 20),

              // Date
              const _FieldLabel('Tanggal'),
              AppCard(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                padding: const EdgeInsets.all(16),
                radius: AppRadius.md,
                shadow: false,
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 18, color: p.brand),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
                          .format(_selectedDate),
                      style: context.texts.bodyMedium,
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, color: p.textMuted, size: 20),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Proof image
              const _FieldLabel('Bukti / Foto Struk (opsional)'),
              _buildImagePicker(),

              // Event allocation
              if (_type == 'Expense') ...[
                const SizedBox(height: 20),
                const _FieldLabel('Alokasi Proker (opsional)'),
                Consumer(
                  builder: (context, ref, child) {
                    final eventsAsync = ref.watch(activeEventsProvider);
                    return eventsAsync.when(
                      data: (events) => DropdownButtonFormField<int>(
                        initialValue: _selectedEventId,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.event_note_rounded),
                          hintText: 'Pilih kegiatan',
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('Tidak ada'),
                          ),
                          ...events.map(
                            (e) => DropdownMenuItem(
                              value: e.id,
                              child: Text(e.name),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _selectedEventId = val),
                      ),
                      loading: () => const SizedBox(),
                      error: (err, _) => const SizedBox(),
                    );
                  },
                ),
              ],

              const SizedBox(height: 34),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saveTransaction,
                  icon: const Icon(Icons.check_rounded, size: 19),
                  label: Text(
                    widget.editTransaction == null
                        ? 'Simpan Transaksi'
                        : 'Update Transaksi',
                  ),
                ),
              ),
            ],
          ),
        ).animate().fade().slideY(
          begin: 0.06,
          end: 0,
          duration: 420.ms,
          curve: Curves.easeOut,
        ),
      ),
    );
  }

  Widget _typeTab(String label, String value, Color color) {
    final selected = _type == value;
    final p = context.palette;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _type = value;
            _selectedCategoryId = null;
            if (value == 'Transfer') {
              _selectedEventId = null;
            } else {
              _selectedTransferAccountId = null;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: selected ? Border.all(color: color.withValues(alpha: 0.5), width: 1.4) : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: p.shadow,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: context.texts.labelMedium?.copyWith(
                color: selected ? color : p.textMuted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg, String label, VoidCallback onAction) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: p.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: p.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: context.texts.bodySmall)),
          TextButton(onPressed: onAction, child: Text(label)),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    final p = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(14),
      radius: AppRadius.md,
      shadow: false,
      child: Column(
        children: [
          if (_imageFile != null) ...[
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImageViewerScreen(imagePath: _imageFile!.path),
                ),
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Hero(
                  tag: 'proofImage',
                  child: Image.file(
                    _imageFile!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 150,
                      width: double.infinity,
                      color: p.surfaceAlt,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_outlined, color: p.textMuted, size: 38),
                          const SizedBox(height: 8),
                          Text(
                            'Gambar tidak ditemukan',
                            style: context.texts.bodySmall?.copyWith(
                              color: p.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _imgButton(Icons.camera_alt_rounded, 'Kamera', () => _pickImage(ImageSource.camera)),
              const SizedBox(width: 10),
              _imgButton(Icons.image_rounded, 'Galeri', () => _pickImage(ImageSource.gallery)),
              if (_imageFile != null) ...[
                const SizedBox(width: 10),
                _imgButton(
                  Icons.delete_outline_rounded,
                  'Hapus',
                  () => setState(() => _imageFile = null),
                  color: p.expense,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _imgButton(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    final p = context.palette;
    final c = color ?? p.brand;
    return Material(
      color: c.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: c),
              const SizedBox(width: 7),
              Text(label, style: context.texts.labelMedium?.copyWith(color: c)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTransaction() async {
    final p = context.palette;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: const Text('Transaksi akan dihapus permanen.'),
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
      final repo = ref.read(transactionRepositoryProvider);
      await repo.deleteTransaction(widget.editTransaction!.transaction.id);
      invalidateAllData(ref);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaksi dihapus')));
        Navigator.pop(context);
      }
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountId == null) {
      _snack('Akun sumber harus dipilih');
      return;
    }

    final repo = ref.read(transactionRepositoryProvider);
    int? categoryId = _selectedCategoryId;
    int? eventId = _selectedEventId;

    if (_type == 'Transfer') {
      if (_selectedTransferAccountId == null) {
        _snack('Akun tujuan harus dipilih');
        return;
      }
      if (_selectedTransferAccountId == _selectedAccountId) {
        _snack('Akun sumber dan tujuan tidak boleh sama');
        return;
      }
      categoryId = await repo.getOrInsertTransferCategory();
      eventId = null;
    } else if (_selectedCategoryId == null) {
      _snack('Kategori harus dipilih');
      return;
    }

    try {
      if (widget.editTransaction != null) {
        await repo.updateTransaction(
          id: widget.editTransaction!.transaction.id,
          amount: _amount,
          type: _type,
          transactionDate: _selectedDate,
          description: _description ?? '',
          accountId: _selectedAccountId!,
          categoryId: categoryId!,
          transferAccountId:
              _type == 'Transfer' ? _selectedTransferAccountId : null,
          eventId: eventId,
        );
        invalidateAllData(ref);
        if (mounted) {
          _snack('Transaksi diperbarui');
          Navigator.pop(context);
        }
      } else {
        await repo.createTransaction(
          amount: _amount,
          type: _type,
          transactionDate: _selectedDate,
          description: _description ?? '',
          accountId: _selectedAccountId!,
          categoryId: categoryId!,
          transferAccountId:
              _type == 'Transfer' ? _selectedTransferAccountId : null,
          eventId: eventId,
        );
        invalidateAllData(ref);
        if (mounted) {
          _snack('Transaksi disimpan');
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) _snack('Error: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: context.texts.titleSmall),
    );
  }
}

class ImageViewerScreen extends StatelessWidget {
  final String imagePath;

  const ImageViewerScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Bukti Transaksi'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(tag: 'proofImage', child: Image.file(File(imagePath), fit: BoxFit.contain)),
        ),
      ),
    );
  }
}
