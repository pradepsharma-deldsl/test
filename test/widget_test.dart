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

  testWidgets('document type dialog can save custom type without framework exception',
      (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showDocumentTypeNameDialog(context);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Insurance');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 'Insurance');
    expect(tester.takeException(), isNull);
  });

  testWidgets('document type dialog can be opened and cancelled repeatedly',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showDocumentTypeNameDialog(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('backup password validation stays inside dialog', (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showBackupPasswordDialog(context, confirm: true);
              },
              child: const Text('Backup'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Backup'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(2));

    await tester.enterText(fields.at(0), '123');
    await tester.enterText(fields.at(1), '123');
    await tester.tap(find.text('Create Backup'));
    await tester.pump();

    expect(find.text('Backup password must be at least 8 characters.'), findsOneWidget);
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });
}
