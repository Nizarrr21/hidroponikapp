// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hydroponic_controller/main.dart';

void main() {
  testWidgets('Hydroponic app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const HydroponicApp());

    // Verify that the app title appears
    expect(find.text('Hydroponic Monitor'), findsOneWidget);

    // Verify that initial loading state may exist
    // This test is intentionally simple as the app requires MQTT connection
  });

  testWidgets('App has home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const HydroponicApp());
    
    // Wait for any async initialization
    await tester.pumpAndSettle();
    
    // The app should build without errors
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}