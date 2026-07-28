import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aset_gudang_komdigi/main.dart';

void main() {
  testWidgets('App dapat dijalankan tanpa error', (WidgetTester tester) async {
    await tester.pumpWidget(const AsetGudangApp());

    // Cukup pastikan splash screen muncul, tanpa expect spesifik
    // karena aplikasi ini bukan aplikasi counter bawaan Flutter.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
