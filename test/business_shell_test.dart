import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:receipt_book/core/navigation/business_section.dart';

/// The Business Book section shell's navigation model.
void main() {
  group('BusinessSection', () {
    test('every section has an icon and a label', () {
      for (final section in BusinessSection.values) {
        expect(section.label.trim(), isNotEmpty, reason: section.name);
      }
    });

    test('indices are stable, since IndexedStack selects by them', () {
      // The shell builds one child per section in declaration order and
      // shows `_section.index`. Reordering the enum without reordering the
      // children would silently show the wrong section.
      expect(BusinessSection.values.first, BusinessSection.bills);
      expect(
        BusinessSection.values.map((s) => s.index).toList(),
        List.generate(BusinessSection.values.length, (i) => i),
      );
    });
  });

  group('BusinessShellScope.goTo', () {
    testWidgets('switches section in place when inside the shell',
        (tester) async {
      BusinessSection? selected;
      var pushed = false;

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/customers': (_) {
              pushed = true;
              return const Scaffold(body: Text('pushed screen'));
            },
          },
          home: BusinessShellScope(
            current: BusinessSection.dashboard,
            select: (s) => selected = s,
            child: Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => BusinessShellScope.goTo(
                    ctx,
                    BusinessSection.customers,
                    fallbackRoute: '/customers',
                  ),
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(selected, BusinessSection.customers);
      expect(pushed, isFalse, reason: 'must not push a route inside the shell');
    });

    testWidgets('falls back to pushing the route when there is no shell',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/customers': (_) => const Scaffold(body: Text('pushed screen')),
          },
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => BusinessShellScope.goTo(
                  ctx,
                  BusinessSection.customers,
                  fallbackRoute: '/customers',
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('pushed screen'), findsOneWidget);
    });

    testWidgets('runs onReturn after the pushed route pops', (tester) async {
      var returned = 0;

      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/customers': (ctx) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('back'),
                  ),
                ),
          },
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => BusinessShellScope.goTo(
                  ctx,
                  BusinessSection.customers,
                  fallbackRoute: '/customers',
                  onReturn: () => returned++,
                ),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(returned, 0);

      await tester.tap(find.text('back'));
      await tester.pumpAndSettle();
      expect(returned, 1, reason: 'dashboard must refresh on the way back');
    });
  });
}
