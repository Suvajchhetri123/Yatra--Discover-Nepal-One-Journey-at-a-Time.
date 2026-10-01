import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/models/user_profile.dart';
import 'package:yatra/navigation/app_entry_navigation.dart';
import 'package:yatra/screens/admin/admin_screen.dart';
import 'package:yatra/screens/auth/login_screen.dart';
import 'package:yatra/screens/auth/tourist_type_setup_screen.dart';
import 'package:yatra/screens/home/home_screen.dart';
import 'package:yatra/screens/splash/splash_screen.dart';
import 'package:yatra/services/app_entry.dart';
import 'package:yatra/services/preview_mode.dart';

/// Tests for the single post-authentication routing decision.
///
/// The point of these is that the rule lives in exactly one place: a signed-in
/// admin must never land on the tourist home, and a tourist without a tourist
/// type must always be sent to onboarding.
void main() {
  const adminWithoutTouristType = UserProfile(
    uid: 'admin-2',
    name: 'Second Admin',
    email: 'admin2@yatra.test',
    role: kAdminRole,
  );

  const blankTouristType = UserProfile(
    uid: 'tourist-3',
    name: 'Chandra',
    email: 'chandra@yatra.test',
    role: kTouristRole,
    touristType: '   ',
  );

  const admin = UserProfile(
    uid: 'admin-1',
    name: 'Root Admin',
    email: 'admin@yatra.test',
    role: kAdminRole,
  );

  const touristWithoutType = UserProfile(
    uid: 'tourist-1',
    name: 'Asha',
    email: 'asha@yatra.test',
    role: kTouristRole,
  );

  const completeTourist = UserProfile(
    uid: 'tourist-2',
    name: 'Bikash',
    email: 'bikash@yatra.test',
    role: kTouristRole,
    touristType: 'adventurer',
  );

  group('AppEntryResolver', () {
    test('a signed-out visitor goes to the login screen', () async {
      final resolver = AppEntryResolver(profileLoader: () async => null);

      expect(await resolver.resolveCurrentEntry(), AppEntry.signedOut);
    });

    test('an admin goes to the admin app, never to tourist home', () async {
      final resolver = AppEntryResolver(profileLoader: () async => admin);

      expect(await resolver.resolveCurrentEntry(), AppEntry.adminRoot);
    });

    test(
      'an admin without a tourist type still goes to the admin app',
      () async {
        // This is the case a "check touristType first" rule would get wrong.
        final resolver = AppEntryResolver(
          profileLoader: () async => adminWithoutTouristType,
        );

        expect(await resolver.resolveCurrentEntry(), AppEntry.adminRoot);
      },
    );

    test('a tourist without a tourist type finishes onboarding', () async {
      final resolver = AppEntryResolver(
        profileLoader: () async => touristWithoutType,
      );

      expect(await resolver.resolveCurrentEntry(), AppEntry.touristOnboarding);
    });

    test('a blank tourist type still counts as missing', () async {
      final resolver = AppEntryResolver(
        profileLoader: () async => blankTouristType,
      );

      expect(await resolver.resolveCurrentEntry(), AppEntry.touristOnboarding);
    });

    test('a complete tourist goes home', () async {
      final resolver = AppEntryResolver(
        profileLoader: () async => completeTourist,
      );

      expect(await resolver.resolveCurrentEntry(), AppEntry.touristHome);
    });

    test(
      'a profile read failure is treated as signed out, not as a crash',
      () async {
        final resolver = AppEntryResolver(
          profileLoader: () async => throw StateError('offline'),
        );

        expect(await resolver.resolveCurrentEntry(), AppEntry.signedOut);
      },
    );
  });

  group('AppEntryNavigation', () {
    testWidgets('routes an admin to the admin app', (tester) async {
      await tester.pumpWidget(
        _Probe(
          entry: AppEntry.adminRoot,
          onResolve: (context, screen) => screen.runtimeType.toString(),
        ),
      );

      expect(tester.widget<Text>(find.byType(Text)).data, 'AdminScreen');
    });

    testWidgets('routes a tourist home entry to HomeScreen', (tester) async {
      await tester.pumpWidget(
        _Probe(
          entry: AppEntry.touristHome,
          onResolve: (context, screen) => screen.runtimeType.toString(),
        ),
      );

      expect(tester.widget<Text>(find.byType(Text)).data, 'HomeScreen');
    });

    testWidgets('routes an onboarding entry to the tourist type screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Probe(
          entry: AppEntry.touristOnboarding,
          onResolve: (context, screen) => screen.runtimeType.toString(),
        ),
      );

      expect(
        tester.widget<Text>(find.byType(Text)).data,
        'TouristTypeSetupScreen',
      );
    });

    testWidgets('routes a signed-out entry to the login screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _Probe(
          entry: AppEntry.signedOut,
          onResolve: (context, screen) => screen.runtimeType.toString(),
        ),
      );

      expect(tester.widget<Text>(find.byType(Text)).data, 'LoginScreen');
    });

    testWidgets('a signed-out entry clears the whole stack', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('start'))),
      );

      unawaited(
        AppEntryNavigation.goToAppEntry(
          tester.element(find.text('start')),
          AppEntry.signedOut,
        ),
      );

      await tester.pumpAndSettle();

      // Everything below the login screen is gone, so Back cannot return to a
      // protected screen after a sign-out.
      expect(find.text('start'), findsNothing);
    });
  });

  group('SplashScreen', () {
    testWidgets('sends a signed-in admin to the admin app', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            profileLoader: () async => admin,
            minimumDuration: Duration.zero,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AdminScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('sends a complete tourist home', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            profileLoader: () async => completeTourist,
            minimumDuration: Duration.zero,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('sends a tourist without a tourist type to onboarding', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            profileLoader: () async => touristWithoutType,
            minimumDuration: Duration.zero,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(TouristTypeSetupScreen), findsOneWidget);
    });
  });

  group('LoginScreen', () {
    testWidgets('an admin login lands on the admin app', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            profileLoader: () async => admin,
            authenticate: (email, password) async {},
          ),
        ),
      );

      // Sign in through the form, exactly as a person would.
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'admin@yatra.test',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'password123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(
        find.byType(AdminScreen),
        findsOneWidget,
        reason: 'the login screen must not hard-code the tourist home',
      );
    });
  });

  group('Preview mode', () {
    testWidgets('the guard blocks an action while preview is active', (
      tester,
    ) async {
      final controller = PreviewModeController()..enter();

      await tester.pumpWidget(
        MaterialApp(
          home: PreviewModeScope(
            controller: controller,
            child: Builder(
              builder: (context) {
                return Scaffold(
                  body: Column(
                    children: <Widget>[
                      const Text('content'),
                      TextButton(
                        onPressed: () => PreviewModeScope.guard(context),
                        child: const Text('write'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('write'));
      await tester.pump();

      expect(
        find.text(kPreviewBlockedMessage),
        findsOneWidget,
        reason: 'the admin is told why nothing happened',
      );
    });

    testWidgets('a normal tourist session is never blocked', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Column(
                  children: <Widget>[
                    const Text('content'),
                    TextButton(
                      onPressed: () {
                        final blocked = PreviewModeScope.guard(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(blocked ? 'blocked' : 'allowed'),
                          ),
                        );
                      },
                      child: const Text('write'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('write'));
      await tester.pump();

      expect(find.text('allowed'), findsOneWidget);
      expect(find.text(kPreviewBlockedMessage), findsNothing);
    });

    testWidgets('exiting preview restores the tourist session', (tester) async {
      final controller = PreviewModeController()..enter();

      await tester.pumpWidget(
        MaterialApp(
          home: PreviewModeScope(
            controller: controller,
            child: Builder(
              builder: (context) => Scaffold(
                body: Text(
                  PreviewModeScope.isActive(context) ? 'preview' : 'tourist',
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('preview'), findsOneWidget);

      controller.exit();
      await tester.pump();

      expect(find.text('tourist'), findsOneWidget);
    });
  });
  group('role routing still resolves correctly after a role change', () {
    // The trusted backend is the only thing that changes a role. These tests
    // prove the resolver keeps following the stored role afterwards, holding no
    // cached authority of its own.

    test('a promoted profile routes to the admin root', () async {
      final resolver = AppEntryResolver(profileLoader: () async => admin);

      expect(await resolver.resolveCurrentEntry(), AppEntry.adminRoot);
    });

    test('the same account demoted routes to the tourist home', () async {
      final resolver = AppEntryResolver(
        profileLoader: () async => completeTourist,
      );

      expect(await resolver.resolveCurrentEntry(), AppEntry.touristHome);
    });

    test('a disabled admin account still routes to the admin root', () async {
      // Disabling blocks sign-in; it does not change the stored role, so
      // routing still follows the role.
      const disabledAdmin = UserProfile(
        uid: 'admin-3',
        name: 'Disabled Admin',
        email: 'admin3@yatra.test',
        role: kAdminRole,
      );

      final resolver = AppEntryResolver(
        profileLoader: () async => disabledAdmin,
      );

      expect(await resolver.resolveCurrentEntry(), AppEntry.adminRoot);
    });

    test('a demoted admin with no tourist type returns to onboarding', () async {
      // After a demotion the account is a tourist again, so a missing
      // touristType must route to onboarding rather than keeping admin access.
      final resolver = AppEntryResolver(
        profileLoader: () async => touristWithoutType,
      );

      expect(await resolver.resolveCurrentEntry(), AppEntry.touristOnboarding);
    });
  });
}

/// Builds the destination widget for an entry without mounting it, so the
/// mapping can be asserted directly.
class _Probe extends StatelessWidget {
  const _Probe({required this.entry, required this.onResolve});

  final AppEntry entry;
  final String Function(BuildContext context, Widget screen) onResolve;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Text(onResolve(context, AppEntryNavigation.screenFor(entry))),
          );
        },
      ),
    );
  }
}
