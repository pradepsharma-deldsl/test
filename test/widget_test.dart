import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secure_doc_mobile/home_page.dart';
import 'package:secure_doc_mobile/main.dart';

void main() {
  test('root app widget can be constructed', () {
    expect(const SecureDocApp(), isA<SecureDocApp>());
  });

  testWidgets('module home shows Document Vault and Event Management', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomePage(onLock: () {})),
    );

    expect(find.text('Document Vault'), findsOneWidget);
    expect(find.text('Event Management'), findsOneWidget);
  });

  testWidgets('Event Management entry opens module shell', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomePage(onLock: () {})),
    );

    await tester.tap(find.text('Event Management'));
    await tester.pumpAndSettle();

    expect(find.text('Event Management module'), findsOneWidget);
    expect(find.textContaining('next development step'), findsOneWidget);
  });
}
