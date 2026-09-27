// Sign-in: the photo headers with the curved edge, email-only login with a
// show/hide password eye, friendly errors, and one tap to log in.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:godoctor_app/core/theme/app_theme.dart';
import 'package:godoctor_app/data/models/enums.dart';
import 'package:godoctor_app/data/providers/repository_providers.dart';
import 'package:godoctor_app/features/auth/screens/login_screen.dart';
import 'package:godoctor_app/features/auth/screens/role_select_screen.dart';
import 'package:godoctor_app/features/auth/widgets/auth_hero.dart';
import 'package:godoctor_app/features/auth/widgets/role_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fakes.dart';

class _Auth extends FakeAuth {
  _Auth({this.error});

  final Object? error;
  int signIns = 0;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signIns++;
    if (error != null) throw error!;
  }

  @override
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required UserRole role,
    required String name,
  }) async => true;
}

Future<void> _render(WidgetTester tester, Widget screen, {_Auth? auth}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth ?? _Auth())],
      child: MaterialApp(theme: AppTheme.patientTheme, home: screen),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('who are you: app icon and the three kinds of account', (
    tester,
  ) async {
    await _render(tester, const RoleSelectScreen());
    expect(find.byType(AppIconMark), findsOneWidget);
    expect(
      find.byType(InwardCurveClipper),
      findsNothing,
    ); // a clipper, not a widget
    expect(find.byType(ClipPath), findsWidgets);
    expect(find.byType(RoleIcon), findsNWidgets(3));
    expect(find.text('I am a patient'), findsOneWidget);
    expect(find.text('I am a doctor'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('I am a chemist'), 100);
    expect(find.text('I am a chemist'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login is email only, with a show/hide password eye', (
    tester,
  ) async {
    await _render(tester, const LoginScreen(role: UserRole.doctor));
    expect(find.text('Log in as a doctor'), findsOneWidget);
    expect(find.textContaining('Phone'), findsNothing);
    expect(find.textContaining('OTP'), findsNothing);

    final field = find.byType(EditableText).last;
    expect(tester.widget<EditableText>(field).obscureText, isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(tester.widget<EditableText>(field).obscureText, isFalse);
    expect(find.byTooltip('Hide password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one tap signs in; bad input is caught before sending', (
    tester,
  ) async {
    final auth = _Auth();
    await _render(
      tester,
      const LoginScreen(role: UserRole.patient),
      auth: auth,
    );

    await tester.tap(find.text('Log in'));
    await tester.pump();
    expect(find.text('Enter your email'), findsOneWidget);
    expect(auth.signIns, 0);

    await tester.enterText(
      find.byType(TextFormField).first,
      'amina@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.tap(find.text('Log in'));
    await tester.pump();
    expect(auth.signIns, 1);
    // Stays busy (no second tap needed or possible) until the app moves on.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
  });

  testWidgets('wrong password shows a plain message', (tester) async {
    final auth = _Auth(error: const AuthException('Invalid login credentials'));
    await _render(
      tester,
      const LoginScreen(role: UserRole.chemist),
      auth: auth,
    );
    await tester.enterText(find.byType(TextFormField).first, 'a@b.co');
    await tester.enterText(find.byType(TextFormField).last, 'nope');
    await tester.tap(find.text('Log in'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('don\'t match'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget, reason: 'can try again');
  });

  testWidgets('registering asks for a name and explains email confirmation', (
    tester,
  ) async {
    await _render(tester, const LoginScreen(role: UserRole.chemist));
    await tester.tap(find.text('New here? Create an account'));
    await tester.pump();
    expect(find.text('Pharmacy name'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Afya Chemist');
    await tester.enterText(fields.at(1), 'afya@example.com');
    await tester.enterText(fields.at(2), 'secret123');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('confirm your email'), findsOneWidget);
  });

  test('the curve rises towards the middle of the bottom edge', () {
    final path = const InwardCurveClipper(
      depth: 30,
    ).getClip(const Size(400, 300));
    expect(path.contains(const Offset(200, 285)), isFalse, reason: 'cut away');
    expect(path.contains(const Offset(5, 298)), isTrue, reason: 'corners stay');
    expect(path.contains(const Offset(200, 260)), isTrue);
  });
}
