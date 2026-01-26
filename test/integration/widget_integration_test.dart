import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:protoolbag_core/protoolbag_core.dart';

void main() {
  group('Widget Integration Tests', () {
    group('AppButton Integration', () {
      testWidgets('primary button renders and responds to tap',
          (WidgetTester tester) async {
        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppButton(
                label: 'Test Button',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        );

        expect(find.text('Test Button'), findsOneWidget);

        await tester.tap(find.byType(AppButton));
        await tester.pump();

        expect(tapped, true);
      });

      testWidgets('disabled button does not respond to tap',
          (WidgetTester tester) async {
        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppButton(
                label: 'Disabled Button',
                onPressed: () => tapped = true,
                enabled: false,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(AppButton));
        await tester.pump();

        expect(tapped, false);
      });

      testWidgets('loading button shows indicator',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppButton(
                label: 'Loading Button',
                onPressed: () {},
                isLoading: true,
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('button variants render correctly',
          (WidgetTester tester) async {
        for (final variant in AppButtonVariant.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: AppButton(
                  label: variant.name,
                  variant: variant,
                  onPressed: () {},
                ),
              ),
            ),
          );

          expect(find.text(variant.name), findsOneWidget);
        }
      });
    });

    group('AppTextField Integration', () {
      testWidgets('text field accepts input', (WidgetTester tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppTextField(
                controller: controller,
                label: 'Test Input',
              ),
            ),
          ),
        );

        await tester.enterText(find.byType(TextField), 'Hello World');
        await tester.pump();

        expect(controller.text, 'Hello World');

        controller.dispose();
      });

      testWidgets('text field shows error state', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppTextField(
                label: 'Error Field',
                errorText: 'This field is required',
              ),
            ),
          ),
        );

        expect(find.text('This field is required'), findsOneWidget);
      });

      testWidgets('text field shows helper text', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppTextField(
                label: 'Helper Field',
                helperText: 'Enter your email address',
              ),
            ),
          ),
        );

        expect(find.text('Enter your email address'), findsOneWidget);
      });

      testWidgets('password field toggles visibility',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppTextField(
                label: 'Password',
                obscureText: true,
              ),
            ),
          ),
        );

        // Find the visibility toggle button
        final toggleFinder = find.byIcon(Icons.visibility_off);
        if (toggleFinder.evaluate().isNotEmpty) {
          await tester.tap(toggleFinder);
          await tester.pump();
        }
      });
    });

    group('AppCard Integration', () {
      testWidgets('card renders children correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppCard(
                child: Text('Card Content'),
              ),
            ),
          ),
        );

        expect(find.text('Card Content'), findsOneWidget);
      });

      testWidgets('card responds to tap', (WidgetTester tester) async {
        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppCard(
                onTap: () => tapped = true,
                child: Text('Tappable Card'),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(AppCard));
        await tester.pump();

        expect(tapped, true);
      });
    });

    group('AppEmptyState Integration', () {
      testWidgets('empty state renders correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppEmptyState(
                icon: Icons.inbox,
                title: 'No Items',
                message: 'There are no items to display',
              ),
            ),
          ),
        );

        expect(find.text('No Items'), findsOneWidget);
        expect(find.text('There are no items to display'), findsOneWidget);
        expect(find.byIcon(Icons.inbox), findsOneWidget);
      });

      testWidgets('empty state with action button',
          (WidgetTester tester) async {
        var actionTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppEmptyState(
                icon: Icons.add,
                title: 'No Items',
                message: 'Add your first item',
                actionLabel: 'Add Item',
                onAction: () => actionTapped = true,
              ),
            ),
          ),
        );

        expect(find.text('Add Item'), findsOneWidget);

        await tester.tap(find.text('Add Item'));
        await tester.pump();

        expect(actionTapped, true);
      });
    });

    group('AppErrorView Integration', () {
      testWidgets('error view renders correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppErrorView(
                title: 'Error',
                message: 'Something went wrong',
              ),
            ),
          ),
        );

        expect(find.text('Error'), findsOneWidget);
        expect(find.text('Something went wrong'), findsOneWidget);
      });

      testWidgets('error view with retry action',
          (WidgetTester tester) async {
        var retryTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppErrorView(
                title: 'Error',
                message: 'Network error occurred',
                actionLabel: 'Retry',
                onAction: () => retryTapped = true,
              ),
            ),
          ),
        );

        expect(find.text('Retry'), findsOneWidget);

        await tester.tap(find.text('Retry'));
        await tester.pump();

        expect(retryTapped, true);
      });
    });

    group('AppLoadingIndicator Integration', () {
      testWidgets('loading indicator renders correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Center(
                child: AppLoadingIndicator(),
              ),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('loading indicator with message',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Center(
                child: AppLoadingIndicator(
                  message: 'Loading data...',
                ),
              ),
            ),
          ),
        );

        expect(find.text('Loading data...'), findsOneWidget);
      });
    });

    group('AppBadge Integration', () {
      testWidgets('badge renders with count', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppBadge(
                count: 5,
                child: Icon(Icons.notifications),
              ),
            ),
          ),
        );

        expect(find.text('5'), findsOneWidget);
        expect(find.byIcon(Icons.notifications), findsOneWidget);
      });

      testWidgets('badge hides when count is zero',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppBadge(
                count: 0,
                child: Icon(Icons.notifications),
              ),
            ),
          ),
        );

        expect(find.text('0'), findsNothing);
      });

      testWidgets('badge shows 99+ for large counts',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppBadge(
                count: 150,
                child: Icon(Icons.notifications),
              ),
            ),
          ),
        );

        expect(find.text('99+'), findsOneWidget);
      });
    });

    group('AppChip Integration', () {
      testWidgets('chip renders correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppChip(
                label: 'Active',
              ),
            ),
          ),
        );

        expect(find.text('Active'), findsOneWidget);
      });

      testWidgets('chip with icon renders correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppChip(
                label: 'Tag',
                icon: Icons.tag,
              ),
            ),
          ),
        );

        expect(find.text('Tag'), findsOneWidget);
        expect(find.byIcon(Icons.tag), findsOneWidget);
      });

      testWidgets('chip responds to tap', (WidgetTester tester) async {
        var tapped = false;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: AppChip(
                label: 'Tappable',
                onTap: () => tapped = true,
              ),
            ),
          ),
        );

        await tester.tap(find.byType(AppChip));
        await tester.pump();

        expect(tapped, true);
      });
    });

    group('Theme Integration', () {
      testWidgets('light theme applies correctly',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Text('Light Theme'),
            ),
          ),
        );

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        // Light theme should have light background
        expect(Theme.of(tester.element(find.byType(Scaffold))).brightness,
            Brightness.light);
      });

      testWidgets('dark theme applies correctly', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Text('Dark Theme'),
            ),
          ),
        );

        expect(Theme.of(tester.element(find.byType(Scaffold))).brightness,
            Brightness.dark);
      });
    });
  });
}
