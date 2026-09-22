import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carnet_vol/main.dart';

void main() {
  testWidgets('App starts and shows the flight logbook title',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const CarnetVolApp());
    // Loading now also awaits an IndexedDB round trip (media flags), which
    // can take a few more microtask/event-loop turns than a couple of pumps.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Carnet de vol'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
