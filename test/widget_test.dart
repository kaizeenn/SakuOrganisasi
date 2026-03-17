// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:apk_bendahara/screens/add_transaction_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  testWidgets('add transaction screen shows transfer option', (
    WidgetTester tester,
  ) async {
    await initializeDateFormatting('id_ID');

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AddTransactionScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Tambah Transaksi'), findsOneWidget);
    expect(find.text('Pemasukan'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);
    expect(find.text('Transfer'), findsOneWidget);
  });
}
