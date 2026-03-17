import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Penting untuk TextInputFormatter
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../providers/dashboard_providers.dart';
import '../repositories/transaction_repository.dart';
import '../utils/currency_format.dart';
import 'master_data_screen.dart';

// KITA BUANG IMPORT LIBRARY CURRENCY DISINI
// import 'package:currency_text_input_formatter/currency_text_input_formatter.dart';

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

  // State Variables
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

    // Initialize Controllers
    _amountController = TextEditingController();
    _descController = TextEditingController();

    // Handle Edit Mode Pre-fill
    if (widget.editTransaction != null) {
      final tx = widget.editTransaction!.transaction;
      _type = tx.type;
      _amount = tx.amount;

      // Manual Formatting untuk Edit Mode
      final formatter = NumberFormat.currency(
        locale: 'id_ID',
        symbol: 'Rp ',
        decimalDigits: 0,
      );
      _amountController.text = formatter.format(tx.amount);

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editTransaction == null
              ? 'Tambah Transaksi'
              : 'Edit Transaksi',
        ),
        actions: [
          if (widget.editTransaction != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteTransaction,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child:
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type Selector
                  Row(
                    children: [
                      Expanded(
                        child: _buildTypeButton(
                          'Pemasukan',
                          'Income',
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTypeButton(
                          'Pengeluaran',
                          'Expense',
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTypeButton(
                          'Transfer',
                          'Transfer',
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Amount Input
                  const Text(
                    'Jumlah',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    // KITA PAKAI FORMATTER MANUAL BUATAN KITA SENDIRI
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      RupiahInputFormatter(),
                    ],
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDarkMode
                          ? Theme.of(context).cardColor
                          : Colors.grey[50],
                      hintText: 'Rp 0',
                    ),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    onChanged: (val) {
                      // Logic simpel: Ambil angka saja, simpan ke _amount
                      // Tidak perlu setState, tidak perlu refresh layar
                      String clean = val.replaceAll(RegExp(r'[^0-9]'), '');
                      _amount = int.tryParse(clean) ?? 0;
                    },
                    validator: (val) =>
                        _amount <= 0 ? 'Jumlah harus > 0' : null,
                  ),

                  const SizedBox(height: 20),

                  // Account Dropdown
                  Text(
                    _type == 'Transfer' ? 'Akun Sumber' : 'Akun',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  accountsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (err, _) => Text(
                      'Error: $err',
                      style: const TextStyle(color: Colors.red),
                    ),
                    data: (accounts) {
                      if (accounts.isEmpty) {
                        return _buildEmptyState('Belum ada Akun.', () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const MasterDataScreen(initialIndex: 0),
                            ),
                          );
                        }, 'Buat Akun');
                      }

                      if (_selectedAccountId == null &&
                          accounts.isNotEmpty &&
                          widget.editTransaction == null) {
                        Future.microtask(() {
                          if (mounted) {
                            setState(
                              () => _selectedAccountId = accounts.first.id,
                            );
                          }
                        });
                      }

                      return DropdownButtonFormField<int>(
                        // ignore: deprecated_member_use
                        value: _selectedAccountId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: isDarkMode
                              ? Theme.of(context).cardColor
                              : null,
                        ),
                        items: accounts
                            .map(
                              (acc) => DropdownMenuItem(
                                value: acc.id,
                                child: Text('${acc.name} (${acc.type})'),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedAccountId = val),
                        validator: (val) => val == null ? 'Pilih Akun' : null,
                      );
                    },
                  ),

                  if (_type == 'Transfer') ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Akun Tujuan',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    accountsAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => Text(
                        'Error: $err',
                        style: const TextStyle(color: Colors.red),
                      ),
                      data: (accounts) {
                        final targetAccounts = accounts
                            .where((acc) => acc.id != _selectedAccountId)
                            .toList();

                        if (_selectedTransferAccountId != null &&
                            !targetAccounts.any(
                              (acc) => acc.id == _selectedTransferAccountId,
                            )) {
                          Future.microtask(() {
                            if (mounted) {
                              setState(() {
                                _selectedTransferAccountId = targetAccounts
                                    .isEmpty
                                    ? null
                                    : targetAccounts.first.id;
                              });
                            }
                          });
                        }

                        if (_selectedTransferAccountId == null &&
                            targetAccounts.isNotEmpty &&
                            widget.editTransaction == null) {
                          Future.microtask(() {
                            if (mounted) {
                              setState(
                                () =>
                                    _selectedTransferAccountId =
                                        targetAccounts.first.id,
                              );
                            }
                          });
                        }

                        if (targetAccounts.isEmpty) {
                          return _buildEmptyState(
                            'Tambahkan minimal 2 akun untuk melakukan transfer.',
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const MasterDataScreen(initialIndex: 0),
                                ),
                              );
                            },
                            'Kelola Akun',
                          );
                        }

                        return DropdownButtonFormField<int>(
                          // ignore: deprecated_member_use
                          value: _selectedTransferAccountId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: isDarkMode
                                ? Theme.of(context).cardColor
                                : null,
                          ),
                          items: targetAccounts
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
                              val == null ? 'Pilih Akun Tujuan' : null,
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Category Dropdown
                  if (_type != 'Transfer') ...[
                    const Text(
                      'Kategori',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    categoriesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (err, _) => Text(
                        'Error: $err',
                        style: const TextStyle(color: Colors.red),
                      ),
                      data: (categories) {
                        final filteredCats = categories
                            .where((c) => c.type == _type)
                            .toList();
                        if (filteredCats.isEmpty) {
                          return _buildEmptyState('Belum ada Kategori.', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const MasterDataScreen(initialIndex: 1),
                              ),
                            );
                          }, 'Buat Kategori');
                        }

                        if (_selectedCategoryId != null &&
                            !filteredCats.any(
                              (c) => c.id == _selectedCategoryId,
                            )) {
                          Future.microtask(() {
                            if (mounted) {
                              setState(() => _selectedCategoryId = null);
                            }
                          });
                        }

                        return DropdownButtonFormField<int>(
                          // ignore: deprecated_member_use
                          value: _selectedCategoryId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: isDarkMode
                                ? Theme.of(context).cardColor
                                : null,
                          ),
                          items: filteredCats
                              .map(
                                (cat) => DropdownMenuItem(
                                  value: cat.id,
                                  child: Text(cat.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedCategoryId = val),
                          validator: (val) =>
                              val == null ? 'Pilih Kategori' : null,
                        );
                      },
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.swap_horiz, color: Colors.blue),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Transfer akan dicatat sebagai perpindahan saldo antar akun tanpa mempengaruhi total pemasukan/pengeluaran.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Description
                  const Text(
                    'Catatan (Opsional)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: isDarkMode
                          ? Theme.of(context).cardColor
                          : Colors.grey[50],
                    ),
                    onChanged: (val) => _description = val,
                  ),

                  const SizedBox(height: 20),

                  // Date Picker
                  const Text(
                    'Tanggal',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDarkMode ? Colors.white24 : Colors.grey,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isDarkMode ? Theme.of(context).cardColor : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat(
                              'dd MMM yyyy',
                              'id_ID',
                            ).format(_selectedDate),
                          ),
                          Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: isDarkMode ? Colors.white70 : Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Proof Image
                  const Text(
                    'Bukti / Foto Struk (Opsional)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _buildImagePicker(isDarkMode),

                  const SizedBox(height: 20),

                  // Event Dropdown
                  if (_type == 'Expense') ...[
                    const Text(
                      'Alokasi Proker / Event (Opsional)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, child) {
                        final eventsAsync = ref.watch(activeEventsProvider);
                        return eventsAsync.when(
                          data: (events) {
                            return DropdownButtonFormField<int>(
                              // ignore: deprecated_member_use
                              value: _selectedEventId,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: isDarkMode
                                    ? Theme.of(context).cardColor
                                    : null,
                                hintText: 'Pilih (Opsional)',
                              ),
                              items: [
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text("Tidak ada"),
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
                            );
                          },
                          loading: () => const SizedBox(),
                          error: (err, _) => const SizedBox(),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 40),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _type == 'Income'
                            ? Colors.green
                            : _type == 'Expense'
                            ? Colors.red
                            : Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _saveTransaction,
                      child: Text(
                        widget.editTransaction == null
                            ? 'Simpan Transaksi'
                            : 'Update Transaksi',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate().fade().slideY(
                begin: 0.1,
                end: 0,
                duration: 500.ms,
                curve: Curves.easeOut,
              ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    String msg,
    VoidCallback onAction,
    String actionLabel,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
          ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }

  Widget _buildImagePicker(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
        color: isDarkMode ? Theme.of(context).cardColor : Colors.grey[50],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          if (_imageFile != null) ...[
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ImageViewerScreen(imagePath: _imageFile!.path),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Hero(
                  tag: 'proofImage',
                  child: Image.file(
                    _imageFile!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 150,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.broken_image,
                              color: Colors.grey,
                              size: 40,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Gambar tidak ditemukan',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Kamera'),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.image),
                label: const Text('Galeri'),
              ),
              if (_imageFile != null) ...[
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () => setState(() => _imageFile = null),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    'Hapus',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(String label, String value, Color color) {
    final isSelected = _type == value;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _type = value;
          _selectedCategoryId = null; // Reset category on type change
          if (value == 'Transfer') {
            _selectedEventId = null;
          } else {
            _selectedTransferAccountId = null;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : (isDarkMode ? Theme.of(context).cardColor : Colors.grey[100]),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? color
                  : (isDarkMode ? Colors.grey[400] : Colors.grey),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTransaction() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi?'),
        content: const Text(
          'Tindakan ini tidak dapat dibatalkan. Transaksi akan dihapus permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final repo = ref.read(transactionRepositoryProvider);
      await repo.deleteTransaction(widget.editTransaction!.transaction);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaksi Dihapus')));
        Navigator.pop(context); // Close Edit Screen
      }
    }
  }

  Future<void> _saveTransaction() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Akun sumber harus dipilih')),
        );
        return;
      }

      final repo = ref.read(transactionRepositoryProvider);
      int? categoryId = _selectedCategoryId;
      int? eventId = _selectedEventId;

      if (_type == 'Transfer') {
        if (_selectedTransferAccountId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Akun tujuan harus dipilih')),
          );
          return;
        }
        if (_selectedTransferAccountId == _selectedAccountId) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Akun sumber dan tujuan tidak boleh sama'),
            ),
          );
          return;
        }
        categoryId = await repo.getOrInsertTransferCategory();
        eventId = null;
      } else if (_selectedCategoryId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kategori harus dipilih')),
        );
        return;
      }

      final entry = TransactionsCompanion(
        id: widget.editTransaction != null
            ? drift.Value(widget.editTransaction!.transaction.id)
            : const drift.Value.absent(),
        amount: drift.Value(_amount),
        type: drift.Value(_type),
        transactionDate: drift.Value(_selectedDate),
        description: drift.Value(_description ?? ''),
        accountId: drift.Value(_selectedAccountId!),
        transferAccountId: drift.Value(
          _type == 'Transfer' ? _selectedTransferAccountId : null,
        ),
        categoryId: drift.Value(categoryId!),
        eventId: drift.Value(eventId),
        proofImage: drift.Value(_imageFile?.path),
        memberId: const drift.Value.absent(),
      );

      try {
        if (widget.editTransaction != null) {
          await repo.updateTransaction(entry);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Transaksi Diupdate')));
            Navigator.pop(context);
          }
        } else {
          await repo.createTransaction(
            entry,
            _selectedAccountId!,
            eventId,
          );
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Transaksi Disimpan')));
            Navigator.pop(context);
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
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
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Bukti Transaksi',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: 'proofImage',
            child: Image.file(File(imagePath), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
