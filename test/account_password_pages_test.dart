import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:global_village_app/pages/change_password_page.dart';
import 'package:global_village_app/pages/forgot_password_page.dart';
import 'package:global_village_app/pages/login_page.dart';
import 'package:global_village_app/services/auth_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> openPage(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
    return Scaffold(
        body: TextButton(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => page),
      ),
      child: const Text('Open account page'),
    ));
  })));
  await tester.tap(find.text('Open account page'));
  await tester.pumpAndSettle();
}

Future<void> press(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> fillAnswers(WidgetTester tester, String value) async {
  for (var index = 1; index <= 3; index++) {
    final field = find.byType(TextFormField).at(index);
    await tester.ensureVisible(field);
    await tester.enterText(field, value);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    AuthService.httpClientOverride?.close();
    AuthService.httpClientOverride = null;
  });

  testWidgets(
      'security recovery verifies server proof and resets without any email endpoint',
      (tester) async {
    final requests = <http.Request>[];
    AuthService.httpClientOverride = MockClient((request) async {
      requests.add(request);
      final body = request.url.path.endsWith('identify')
          ? {
              'questions': [
                'What is your favourite food?',
                'What city were you born in?',
                'What is your childhood nickname?'
              ],
              'challenge': 'challenge'
            }
          : request.url.path.endsWith('verify')
              ? {'resetToken': 'verified-proof', 'expiresInSeconds': 300}
              : {'message': 'Password Reset Successfully'};
      return http.Response(jsonEncode(body), 200);
    });
    await openPage(tester, const ForgotPasswordPage());
    await tester.tap(find.text('Security Question'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'student');
    await press(tester, 'Continue');
    expect(find.text('What is your favourite food?'), findsOneWidget);
    await fillAnswers(tester, 'answer');
    await press(tester, 'Verify Answers');
    expect(find.text('Confirm New Password'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'new-password');
    await tester.enterText(find.byType(TextFormField).at(1), 'different');
    await press(tester, 'Reset Password');
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(requests.length, 2);
    await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
    await press(tester, 'Reset Password');
    expect(find.text('Open account page'), findsOneWidget);
    expect(requests.map((r) => r.url.path).toList(), [
      '/auth/security-question/identify',
      '/auth/security-question/verify',
      '/auth/security-question/reset',
    ]);
    expect(jsonDecode(requests.last.body)['resetToken'], 'verified-proof');
  });

  testWidgets(
      'switching recovery methods clears answers, passwords and account inputs',
      (tester) async {
    AuthService.httpClientOverride = MockClient((_) async => http.Response(
          jsonEncode({
            'questions': [
              'What is your favourite food?',
              'What city were you born in?',
              'What is your childhood nickname?'
            ],
            'challenge': 'challenge'
          }),
          200,
        ));
    await openPage(tester, const ForgotPasswordPage());
    await tester.enterText(
        find.byType(TextFormField).at(0), 'student@example.com');
    await tester.enterText(
        find.byType(TextFormField).at(2), 'sensitive-password');
    await tester.ensureVisible(find.text('Security Question'));
    await tester.tap(find.text('Security Question'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        isEmpty);
    await tester.enterText(find.byType(TextFormField).at(0), 'student');
    await press(tester, 'Continue');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'sensitive-answer');
    await tester.ensureVisible(find.text('Email Verification'));
    await tester.tap(find.text('Email Verification'));
    await tester.pumpAndSettle();
    for (final field
        in tester.widgetList<TextFormField>(find.byType(TextFormField))) {
      expect(field.controller!.text, isEmpty);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('wrong security answer stays on answer step and never resets',
      (tester) async {
    final requests = <http.Request>[];
    AuthService.httpClientOverride = MockClient((request) async {
      requests.add(request);
      return request.url.path.endsWith('identify')
          ? http.Response(
              jsonEncode({
                'questions': [
                  'What is your favourite food?',
                  'What city were you born in?',
                  'What is your childhood nickname?'
                ],
                'challenge': 'challenge'
              }),
              200)
          : http.Response(
              jsonEncode({'error': 'Unable to verify this account or answer.'}),
              400);
    });
    await openPage(tester, const ForgotPasswordPage());
    await tester.tap(find.text('Security Question'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'student');
    await press(tester, 'Continue');
    await fillAnswers(tester, 'wrong');
    await press(tester, 'Verify Answers');
    expect(
        find.text('Unable to verify this account or answer.'), findsOneWidget);
    expect(find.text('Confirm New Password'), findsNothing);
    expect(requests.length, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'password change validates confirmation, sends JWT and signs out only after server success',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'auth_token': 'existing-jwt', 'auth_user': '{}'});
    final requests = <http.Request>[];
    AuthService.httpClientOverride = MockClient((request) async {
      requests.add(request);
      return http.Response(
          jsonEncode({
            'message': 'Password changed successfully. Please sign in again.'
          }),
          200);
    });
    await openPage(tester, const ChangePasswordPage());
    await tester.enterText(find.byType(TextFormField).at(0), 'old-password');
    await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
    await tester.enterText(find.byType(TextFormField).at(2), 'different');
    await press(tester, 'Change Password');
    expect(find.text('Passwords do not match.'), findsOneWidget);
    expect(requests, isEmpty);
    await tester.enterText(find.byType(TextFormField).at(2), 'new-password');
    await press(tester, 'Change Password');
    expect(requests.single.url.path, '/auth/change-password');
    expect(requests.single.headers['Authorization'], 'Bearer existing-jwt');
    expect(await AuthService.getAuthToken(), isNull);
    expect(find.byType(ChangePasswordPage), findsNothing);
    expect(find.text('Password changed successfully. Please sign in again.'),
        findsOneWidget);
  });

  testWidgets(
      'password change failure preserves login and does not show success',
      (tester) async {
    SharedPreferences.setMockInitialValues({'auth_token': 'existing-jwt'});
    AuthService.httpClientOverride = MockClient((_) async => http.Response(
          jsonEncode({'error': 'Current password is incorrect.'}),
          400,
        ));
    await openPage(tester, const ChangePasswordPage());
    await tester.enterText(find.byType(TextFormField).at(0), 'wrong-password');
    await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
    await tester.enterText(find.byType(TextFormField).at(2), 'new-password');
    await press(tester, 'Change Password');
    expect(find.text('Current password is incorrect.'), findsOneWidget);
    expect(await AuthService.getAuthToken(), 'existing-jwt');
    expect(find.byType(ChangePasswordPage), findsOneWidget);
    expect(find.text('Password changed successfully. Please sign in again.'),
        findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'header and system back return to account, clear proofs and permit a different account',
      (tester) async {
    final requests = <http.Request>[];
    AuthService.httpClientOverride = MockClient((request) async {
      requests.add(request);
      return http.Response(
          jsonEncode(request.url.path.endsWith('identify')
              ? {
                  'questions': [
                    'First school?',
                    'Favourite food?',
                    'Birth city?'
                  ],
                  'challenge': 'challenge-${requests.length}'
                }
              : {'resetToken': 'old-proof'}),
          200);
    });
    await openPage(tester, const ForgotPasswordPage());
    await tester.tap(find.text('Security Question'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('security-account')), 'first-account');
    await press(tester, 'Continue');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordPage), findsOneWidget);
    expect(find.text('Question 1'), findsNothing);
    expect(
        tester
            .widget<TextField>(find.descendant(
                of: find.byKey(const ValueKey('security-account')),
                matching: find.byType(TextField)))
            .readOnly,
        false);
    await tester.enterText(
        find.byKey(const ValueKey('security-account')), 'second-account');
    await press(tester, 'Continue');
    expect(jsonDecode(requests.last.body)['account'], 'second-account');
    await fillAnswers(tester, 'answer');
    await press(tester, 'Verify Answers');
    await tester.enterText(
        find.byType(TextFormField).first, 'sensitive-password');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordPage), findsOneWidget);
    expect(find.text('Confirm New Password'), findsNothing);
    expect(find.text('Continue'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('security-account')), 'third-account');
    await press(tester, 'Continue');
    expect(requests.last.url.path, '/auth/security-question/identify');
    expect(jsonDecode(requests.last.body)['account'], 'third-account');
    for (final field in tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .skip(1)) {
      expect(field.controller!.text, isEmpty);
    }
    await tester.ensureVisible(find.text('Back to Login'));
    await tester.tap(find.text('Back to Login'));
    await tester.pumpAndSettle();
    expect(find.text('Open account page'), findsOneWidget);
    expect(
        requests.any((request) => request.url.path.endsWith('/reset')), false);
  });

  testWidgets(
      'Change Password back button receives taps and preserves the session',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'auth_token': 'existing-jwt', 'auth_user': '{"id":"student"}'});
    await openPage(tester, const ChangePasswordPage());
    expect(find.byTooltip('Back').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open account page'), findsOneWidget);
    expect(await AuthService.getAuthToken(), 'existing-jwt');
    expect((await AuthService.getCurrentUser())?['id'], 'student');
  });

  testWidgets('blue recovery link is below Current Password and opens once',
      (tester) async {
    SharedPreferences.setMockInitialValues({'auth_token': 'existing-jwt'});
    await openPage(tester, const ChangePasswordPage());
    expect(find.text('Global Village'), findsOneWidget);
    expect(find.byTooltip('Show password'), findsNWidgets(3));
    final fields = find.byType(TextFormField);
    final link = find.widgetWithText(TextButton, 'Forgot Password?');
    final current = tester.getRect(fields.at(0));
    final button = tester.getRect(link);
    expect(button.top, greaterThanOrEqualTo(current.bottom));
    expect(button.right, moreOrLessEquals(current.right));
    expect(button.bottom, lessThan(tester.getTopLeft(fields.at(1)).dy));
    expect(tester.widget<TextButton>(link).style!.foregroundColor!.resolve({}),
        Colors.blue.shade800);

    await tester.enterText(fields.first, 'current-draft');
    await tester.tap(link);
    await tester.tapAt(button.center);
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordPage, skipOffstage: false), findsOneWidget);
    expect(find.text('Email Verification'), findsOneWidget);
    expect(find.text('Security Question'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordPage, skipOffstage: false), findsNothing);
    expect(find.byType(ChangePasswordPage), findsOneWidget);
    expect(tester.widget<TextFormField>(fields.first).controller!.text,
        'current-draft');
    expect(await AuthService.getAuthToken(), 'existing-jwt');

    await tester.tap(link);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordPage), findsOneWidget);
    expect(find.byType(ForgotPasswordPage, skipOffstage: false), findsNothing);
    expect(await AuthService.getAuthToken(), 'existing-jwt');
  });

  testWidgets('email recovery from Change Password signs out and opens Login',
      (tester) async {
    SharedPreferences.setMockInitialValues({'auth_token': 'existing-jwt'});
    final requests = <http.Request>[];
    AuthService.httpClientOverride = MockClient((request) async {
      requests.add(request);
      final body = request.url.path.endsWith('forgot-password')
          ? {'message': 'Check your email.', 'retryAfterSeconds': 60}
          : {'message': 'Password reset successfully.'};
      return http.Response(jsonEncode(body), 200);
    });
    await openPage(tester, const ChangePasswordPage());
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'student@outlook.com');
    await tester.ensureVisible(find.text('Send Code'));
    await tester.tap(find.text('Send Code'));
    await tester.pumpAndSettle();
    expect(await AuthService.getAuthToken(), 'existing-jwt');
    await tester.enterText(fields.at(1), '123456');
    await tester.enterText(fields.at(2), 'new-password');
    await tester.enterText(fields.at(3), 'new-password');
    await press(tester, 'Reset Password');

    expect(requests.map((request) => request.url.path),
        ['/auth/forgot-password', '/auth/reset-password']);
    expect(jsonDecode(requests.last.body), {
      'email': 'student@outlook.com',
      'code': '123456',
      'newPassword': 'new-password',
    });
    expect(await AuthService.getAuthToken(), isNull);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(ChangePasswordPage, skipOffstage: false), findsNothing);
    expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(), false);
  });

  testWidgets(
      'security recovery from Change Password requires proof and opens Login',
      (tester) async {
    SharedPreferences.setMockInitialValues({'auth_token': 'existing-jwt'});
    final requests = <http.Request>[];
    AuthService.httpClientOverride = MockClient((request) async {
      requests.add(request);
      final body = request.url.path.endsWith('identify')
          ? {
              'questions': ['First school?', 'Favourite food?', 'Birth city?'],
              'challenge': 'challenge'
            }
          : request.url.path.endsWith('verify')
              ? {'resetToken': 'verified-proof'}
              : {'message': 'Password reset successfully.'};
      return http.Response(jsonEncode(body), 200);
    });
    await openPage(tester, const ChangePasswordPage());
    await tester.tap(find.text('Forgot Password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Security Question'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'student');
    await press(tester, 'Continue');
    await fillAnswers(tester, 'answer');
    await press(tester, 'Verify Answers');
    expect(await AuthService.getAuthToken(), 'existing-jwt');
    await tester.enterText(fields.at(0), 'new-password');
    await tester.enterText(fields.at(1), 'new-password');
    await press(tester, 'Reset Password');

    expect(requests.map((request) => request.url.path), [
      '/auth/security-question/identify',
      '/auth/security-question/verify',
      '/auth/security-question/reset',
    ]);
    expect(jsonDecode(requests.last.body)['resetToken'], 'verified-proof');
    expect(await AuthService.getAuthToken(), isNull);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(ChangePasswordPage, skipOffstage: false), findsNothing);
    expect(tester.state<NavigatorState>(find.byType(Navigator)).canPop(), false);
  });
}
