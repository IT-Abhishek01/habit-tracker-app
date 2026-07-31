import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_tracker_app/main.dart';

void main() {
  testWidgets('Habit tracker opens', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const HabitTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Add habit'), findsWidgets);
    expect(
      find.widgetWithText(FloatingActionButton, 'Add habit'),
      findsOneWidget,
    );
  });

  testWidgets('creates a habit from the add sheet', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const HabitTrackerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add habit'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Read 10 pages');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Read 10 pages'), findsOneWidget);
    expect(find.text('0/7 week'), findsOneWidget);
  });
}
