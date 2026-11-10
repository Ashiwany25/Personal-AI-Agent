
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_ai_agent/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Personal AI Agent login screen loads',
    (WidgetTester tester) async {
      // Test the login screen directly.
      // No Supabase initialization or network call is needed.
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginPage(),
        ),
      );

      // Check application title.
      expect(
        find.text('Personal AI Agent'),
        findsOneWidget,
      );

      // Check login heading.
      expect(
        find.text('Welcome back'),
        findsOneWidget,
      );

      // Check login button.
      expect(
        find.text('Log In'),
        findsOneWidget,
      );

      // Check signup navigation.
      expect(
        find.text('New user? Create an account'),
        findsOneWidget,
      );

      // Check email and password inputs.
      expect(
        find.byType(TextField),
        findsNWidgets(2),
      );

      // Switch to signup mode.
      await tester.tap(
        find.text('New user? Create an account'),
      );

      await tester.pump();

      // Verify signup screen.
      expect(
        find.text('Create your personal account'),
        findsOneWidget,
      );

      expect(
        find.text('Sign Up'),
        findsOneWidget,
      );

      // Return to login mode.
      await tester.tap(
        find.text('Already have an account? Log In'),
      );

      await tester.pump();

      expect(
        find.text('Welcome back'),
        findsOneWidget,
      );
    },
  );
}
