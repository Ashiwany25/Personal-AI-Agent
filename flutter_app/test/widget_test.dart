import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_agent/main.dart';

void main() {
  testWidgets('App has chat, notes and tasks', (tester) async {
    await tester.pumpWidget(const PersonalAiApp());
    expect(find.text('Personal AI Agent'), findsOneWidget);
    expect(find.byIcon(Icons.chat_outlined), findsOneWidget);
    expect(find.byIcon(Icons.note_outlined), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });
}
