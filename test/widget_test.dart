import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carnet_vol/main.dart';

void main() {
  testWidgets('App starts and shows the flight logbook title',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const CarnetVolApp());
    await tester.pump();
    await tester.pump();

    expect(find.text('Carnet de vol'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
