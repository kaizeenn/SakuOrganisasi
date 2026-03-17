import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// CUSTOM FORMATTER
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 1. Jika kosong, kembalikan kosong
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // 2. Bersihkan semua karakter selain angka
    // Contoh: "Rp 10.000a" -> "10000"
    String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Jika hasilnya kosong (misal user hapus semua angka), return kosong
    if (newText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // 3. Format ke Rupiah
    final int value = int.parse(newText);
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    String formatted = formatter.format(value);

    // 4. Kembalikan value baru dengan kursor di paling belakang (Safe)
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
