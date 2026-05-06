import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eggplant_app/main.dart'; // Ensure project name is correct

void main() {
  testWidgets('Eggplant App UI and Flow Test', (WidgetTester tester) async {
    // Start the app
    await tester.pumpWidget(const MaterialApp(home: EggplantHome()));

    // Verify Default Language (Bengali)
    expect(find.text('বেগুন সুরক্ষা'), findsOneWidget);

    // Test Language Toggle
    final languageBtn = find.byType(TextButton);
    await tester.tap(languageBtn);
    await tester.pump(); // Rebuild UI

    // Verify English Translation
    expect(find.text('Eggplant Shield'), findsOneWidget);

    // Verify Action Buttons presence
    expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.photo_library_rounded), findsOneWidget);
  });
}