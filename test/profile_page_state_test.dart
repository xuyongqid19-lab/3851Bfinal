import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_village_app/pages/profile_page.dart';
import 'package:global_village_app/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpProfile(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: const ProfilePage(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('offline profile keeps Edit usable but disables Save',
      (tester) async {
    await pumpProfile(tester);

    // The server could not be reached, so the fallback must not be written back.
    expect(find.text('Profile not synced'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('switching profile tabs keeps an unsaved edit', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Draft that must survive',
    );

    await tester.tap(find.text('Interest Match'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Draft that must survive'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('logout asks for confirmation before clearing the session',
      (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.byTooltip('Logout'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.text('Log out?'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
