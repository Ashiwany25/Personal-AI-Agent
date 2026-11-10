
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_agent/main.dart';

void main() {
  testWidgets('Personal AI Agent login screen loads', (tester) async {
    await tester.pumpWidget(const PersonalAiApp());

    expect(find.text('Personal AI Agent'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('New user? Create an account'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
