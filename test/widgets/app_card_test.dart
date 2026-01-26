import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  group('AppCard', () {
    testWidgets('renders child correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: const Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              onTap: () => wasTapped = true,
              child: const Text('Tappable Card'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tappable Card'));
      expect(wasTapped, true);
    });

    testWidgets('applies padding correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Padded Content'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Padded Content'), findsOneWidget);
    });

    testWidgets('different variants render correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppCard(
                  variant: AppCardVariant.elevated,
                  child: const Text('Elevated'),
                ),
                AppCard(
                  variant: AppCardVariant.outlined,
                  child: const Text('Outlined'),
                ),
                AppCard(
                  variant: AppCardVariant.filled,
                  child: const Text('Filled'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Elevated'), findsOneWidget);
      expect(find.text('Outlined'), findsOneWidget);
      expect(find.text('Filled'), findsOneWidget);
    });
  });

  group('MetricCard', () {
    testWidgets('renders title and value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricCard(
              title: 'Total Users',
              value: '1,234',
            ),
          ),
        ),
      );

      expect(find.text('Total Users'), findsOneWidget);
      expect(find.text('1,234'), findsOneWidget);
    });

    testWidgets('shows icon when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricCard(
              title: 'Users',
              value: '100',
              icon: Icons.people,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.people), findsOneWidget);
    });

    testWidgets('shows trend indicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricCard(
              title: 'Revenue',
              value: '\$10,000',
              trend: MetricTrend.up,
              trendValue: '+15%',
            ),
          ),
        ),
      );

      expect(find.text('+15%'), findsOneWidget);
    });

    testWidgets('applies custom color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricCard(
              title: 'Status',
              value: 'Active',
              color: Colors.green,
            ),
          ),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
    });
  });
}
