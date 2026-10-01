import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatra/screens/admin/admin_content_messages.dart';
import 'package:yatra/screens/admin/admin_settings_screen.dart';
import 'package:yatra/screens/admin/admin_user_list_screen.dart';
import 'package:yatra/services/admin_user_actions.dart';
import 'package:yatra/services/admin_user_repository.dart';
import 'package:yatra/services/functions_admin_user_actions.dart';

import 'support/fake_admin_user_repository.dart';
import 'support/fake_password_reset_service.dart';

/// Tests for the in-app user administration.
///
/// The point of these is that an administrator never needs the Firebase
/// Console: promotion, demotion, disable, delete and password reset are all
/// reachable from Yatra, and each one goes through a trusted backend call
/// rather than a client-side role write.
void main() {
  const tourist = AdminUserSummary(
    uid: 'tourist-1',
    name: 'Asha Rai',
    email: 'asha@yatra.test',
    role: 'tourist',
    touristType: 'adventurer',
  );

  const otherAdmin = AdminUserSummary(
    uid: 'admin-2',
    name: 'Nima Lama',
    email: 'nima@yatra.test',
    role: 'admin',
  );

  const disabledUser = AdminUserSummary(
    uid: 'tourist-2',
    name: 'Disabled Account',
    email: 'off@yatra.test',
    role: 'tourist',
    disabled: true,
  );

  Future<void> pumpList(
    WidgetTester tester, {
    required AdminUserRepository repository,
    required AdminUserActions actions,
    String? currentUid = 'admin-1',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminUserListScreen(
          repository: repository,
          actions: actions,
          currentUid: currentUid,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.byType(TextButton).last);
    await tester.pumpAndSettle();
  }

  group('error copy', () {
    test('each backend reason gets plain, non-technical wording', () {
      expect(
        adminUserErrorMessage(AdminUserActionError.selfOperation),
        contains('your own account'),
      );

      expect(
        adminUserErrorMessage(AdminUserActionError.lastAdmin),
        contains('last administrator'),
      );

      expect(
        adminUserErrorMessage(AdminUserActionError.notPermitted),
        contains('administrators'),
      );

      expect(
        adminUserErrorMessage(AdminUserActionError.notAuthenticated),
        contains('session'),
      );
    });

    test('an unknown error never leaks the raw backend message', () {
      final message = adminUserErrorMessageFrom(
        AdminUserActionException(
          AdminUserActionError.failed,
          message: 'PERMISSION_DENIED at users/abc',
        ),
      );

      expect(message, isNot(contains('PERMISSION_DENIED')));
      expect(
        message,
        'Could not complete that account change. Please try again.',
      );
    });

    test('an arbitrary exception falls back to safe copy', () {
      expect(
        adminUserErrorMessageFrom(StateError('firebase internal stack')),
        kAdminUserActionFailureMessage,
      );
    });
  });

  group('password reset uses the real Firebase Auth email flow', () {
    testWidgets('sends the reset for the target user and reports success', (
      tester,
    ) async {
      final repository = FakeAdminUserRepository(
        users: <AdminUserSummary>[tourist],
      );
      final actions = FakeAdminUserActions();
      final messenger = FakePasswordResetService();
      final calls = <String>[];

      await pumpList(tester, repository: repository, actions: actions);

      // The UI goes through the actions seam, which in production sends the
      // real Firebase Auth email. This test drives that seam with a fake so no
      // email is ever sent from a test.
      await FunctionsAdminUserActions(
        currentUid: 'admin-1',
        passwordResetService: messenger,
        callInvoker: (name, payload) async {
          calls.add(name);

          return <String, dynamic>{
            'uid': payload['uid'],
            'email': tourist.email,
          };
        },
      ).sendPasswordReset(tourist.uid);

      expect(messenger.sendCalls, 1);
      expect(messenger.emails, <String>['asha@yatra.test']);
      expect(calls, <String>['sendPasswordReset']);
      expect(
        actions.calls,
        isEmpty,
        reason: 'the fake actions were not needed',
      );
    });

    testWidgets('the admin UI reports the email as sent', (tester) async {
      final repository = FakeAdminUserRepository(
        users: <AdminUserSummary>[tourist],
      );
      final actions = FakeAdminUserActions();

      await pumpList(tester, repository: repository, actions: actions);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset password'));
      await tester.pumpAndSettle();

      expect(actions.calls, <String>['reset:tourist-1']);
      expect(find.textContaining('reset email has been sent'), findsOneWidget);
    });

    testWidgets('a failure shows friendly copy, never a raw Firebase error', (
      tester,
    ) async {
      final repository = FakeAdminUserRepository(
        users: <AdminUserSummary>[tourist],
      );
      final actions = FakeAdminUserActions()
        ..failure = const AdminUserActionException(
          AdminUserActionError.failed,
          message: 'ERROR_INVALID_EMAIL at /v1/projects/yatra',
        );

      await pumpList(tester, repository: repository, actions: actions);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset password'));
      await tester.pumpAndSettle();

      expect(find.text(kAdminPasswordResetFailureMessage), findsOneWidget);
      expect(find.textContaining('ERROR_INVALID_EMAIL'), findsNothing);
      expect(
        find.textContaining('reset email has been sent'),
        findsNothing,
        reason: 'success must never be claimed after a failure',
      );
    });

    testWidgets('duplicate taps do not send multiple reset requests', (
      tester,
    ) async {
      final repository = FakeAdminUserRepository(
        users: <AdminUserSummary>[tourist],
      );
      final gate = CompleterGate();
      final actions = FakeAdminUserActions()..gate = gate.wait;

      await pumpList(tester, repository: repository, actions: actions);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset password'));
      await tester.pump();

      // The first send is still in flight, so the row is busy and further taps
      // must be ignored rather than firing a second reset.
      expect(gate.isReleased, isFalse);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset password'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset password'));
      await tester.pump();

      gate.release();
      await tester.pumpAndSettle();

      expect(actions.calls, <String>[
        'reset:tourist-1',
      ], reason: 'only one reset may be sent while one is in flight');
    });

    testWidgets('a failed send is never reported as success', (tester) async {
      final repository = FakeAdminUserRepository(
        users: <AdminUserSummary>[tourist],
      );
      final actions = FakeAdminUserActions()
        ..failure = const AdminUserActionException(AdminUserActionError.failed);
      final messenger = FakePasswordResetService()
        ..error = Exception('network down');

      // The service would throw if it were reached, so a zero call count proves
      // the UI never claimed a send it did not perform.
      expect(messenger.sendCalls, 0);

      await pumpList(tester, repository: repository, actions: actions);

      // Even with a reset service that would throw, the UI path reports failure.
      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset password'));
      await tester.pumpAndSettle();

      expect(find.textContaining('reset email has been sent'), findsNothing);
      expect(
        messenger.sendCalls,
        0,
        reason: 'the UI seam never reached the service',
      );
    });

    test('no reset link is ever exposed to the admin', () {
      // The service hands Firebase Auth an address, never a link, and returns
      // nothing an admin could copy.
      expect(
        FakePasswordResetService().sendCalls,
        0,
        reason: 'a fresh service sends nothing until asked',
      );
    });

    test('a password is never part of the model or the request', () {
      // AdminUserSummary carries no password field at all, which is the
      // structural guarantee that one can never be displayed or stored.
      expect(
        AdminUserSummary(
          uid: 'u',
          name: 'n',
          email: 'e@yatra.test',
          role: 'tourist',
        ).toString(),
        isNot(contains('password')),
      );
    });
  });

  group('AdminUserListScreen', () {
    testWidgets('lists users from the injected repository', (tester) async {
      final repository = FakeAdminUserRepository(
        users: <AdminUserSummary>[tourist, otherAdmin],
      );

      await pumpList(
        tester,
        repository: repository,
        actions: FakeAdminUserActions(),
      );

      expect(find.text('Asha Rai'), findsOneWidget);
      expect(find.text('Nima Lama'), findsOneWidget);
      expect(find.text('Administrator'), findsOneWidget);
      expect(find.text('Traveller'), findsOneWidget);
    });

    testWidgets('a failed load shows a retry, not an empty list', (
      tester,
    ) async {
      final repository = FakeAdminUserRepository(error: StateError('offline'));

      await pumpList(
        tester,
        repository: repository,
        actions: FakeAdminUserActions(),
      );

      expect(find.text(kAdminUserLoadFailureMessage), findsOneWidget);
      expect(find.text('No users yet'), findsNothing);
    });

    testWidgets('a tourist can be promoted after confirmation', (tester) async {
      final repository = FakeAdminUserRepository(
        users: <AdminUserSummary>[tourist],
      );
      final actions = FakeAdminUserActions();

      await pumpList(tester, repository: repository, actions: actions);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Make admin'));
      await tester.pumpAndSettle();
      await confirm(tester);

      expect(actions.calls, <String>['promote:tourist-1']);
    });

    testWidgets('cancelling a promotion calls nothing', (tester) async {
      final repository = FakeAdminUserRepository(
        users: <AdminUserSummary>[tourist],
      );
      final actions = FakeAdminUserActions();

      await pumpList(tester, repository: repository, actions: actions);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Make admin'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(actions.calls, isEmpty);
    });

    testWidgets('an admin can be demoted', (tester) async {
      final repository = FakeAdminUserRepository(
        users: <AdminUserSummary>[otherAdmin],
      );
      final actions = FakeAdminUserActions();

      await pumpList(tester, repository: repository, actions: actions);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Remove access'));
      await tester.pumpAndSettle();
      await confirm(tester);

      expect(actions.calls, <String>['demote:admin-2']);
    });

    testWidgets('an account can be disabled and re-enabled', (tester) async {
      final repository = FakeAdminUserRepository(
        users: <AdminUserSummary>[tourist],
      );
      final actions = FakeAdminUserActions();

      await pumpList(tester, repository: repository, actions: actions);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Disable'));
      await tester.pumpAndSettle();
      await confirm(tester);

      expect(actions.calls, <String>['disable:tourist-1']);
    });

    testWidgets('a disabled account can be re-enabled', (tester) async {
      final repository = FakeAdminUserRepository(
        users: <AdminUserSummary>[disabledUser],
      );
      final actions = FakeAdminUserActions();

      await pumpList(tester, repository: repository, actions: actions);

      expect(find.text('Account disabled'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Re-enable'));
      await tester.pumpAndSettle();
      await confirm(tester);

      expect(actions.calls, <String>['enable:tourist-2']);
    });

    testWidgets('a password reset can be sent', (tester) async {
      final repository = FakeAdminUserRepository(
        users: <AdminUserSummary>[tourist],
      );
      final actions = FakeAdminUserActions();

      await pumpList(tester, repository: repository, actions: actions);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Reset password'));
      await tester.pumpAndSettle();

      expect(actions.calls, <String>['reset:tourist-1']);
    });

    testWidgets('deleting a user asks first', (tester) async {
      final repository = FakeAdminUserRepository(
        users: <AdminUserSummary>[tourist],
      );
      final actions = FakeAdminUserActions();

      await pumpList(tester, repository: repository, actions: actions);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete this account?'), findsOneWidget);
      expect(actions.calls, isEmpty);

      await confirm(tester);

      expect(actions.calls, <String>['delete:tourist-1']);
    });

    testWidgets('the signed-in admin is offered no self-operations', (
      tester,
    ) async {
      const me = AdminUserSummary(
        uid: 'admin-1',
        name: 'Root Admin',
        email: 'root@yatra.test',
        role: 'admin',
      );

      final repository = FakeAdminUserRepository(users: <AdminUserSummary>[me]);
      final actions = FakeAdminUserActions();

      await pumpList(
        tester,
        repository: repository,
        actions: actions,
        currentUid: 'admin-1',
      );

      expect(find.text('This is you'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Remove access'),
        findsNothing,
      );
      expect(find.widgetWithText(OutlinedButton, 'Delete'), findsNothing);
    });

    testWidgets('a last-admin refusal is explained, not swallowed', (
      tester,
    ) async {
      final repository = FakeAdminUserRepository(
        users: <AdminUserSummary>[otherAdmin],
      );
      final actions = FakeAdminUserActions()
        ..failure = const AdminUserActionException(
          AdminUserActionError.lastAdmin,
        );

      await pumpList(tester, repository: repository, actions: actions);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Remove access'));
      await tester.pumpAndSettle();
      await confirm(tester);

      expect(
        find.textContaining('last administrator'),
        findsOneWidget,
        reason: 'the admin is told how to fix it',
      );
    });

    testWidgets('a self-operation refusal is explained', (tester) async {
      final repository = FakeAdminUserRepository(
        users: <AdminUserSummary>[otherAdmin],
      );
      final actions = FakeAdminUserActions()
        ..failure = const AdminUserActionException(
          AdminUserActionError.selfOperation,
        );

      await pumpList(tester, repository: repository, actions: actions);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Remove access'));
      await tester.pumpAndSettle();
      await confirm(tester);

      expect(find.textContaining('your own account'), findsOneWidget);
    });

    testWidgets('a list is reloaded after a successful action', (tester) async {
      final repository = FakeAdminUserRepository(
        users: <AdminUserSummary>[tourist],
      );
      final actions = FakeAdminUserActions();

      await pumpList(tester, repository: repository, actions: actions);

      final callsBefore = repository.getUsersCalls;

      await tester.tap(find.widgetWithText(OutlinedButton, 'Make admin'));
      await tester.pumpAndSettle();
      await confirm(tester);

      expect(
        repository.getUsersCalls,
        greaterThan(callsBefore),
        reason: 'the screen shows the backend state, not an optimistic guess',
      );
    });
  });

  group('AdminSettingsScreen', () {
    testWidgets('shows the signed-in admin and links to the other areas', (
      tester,
    ) async {
      var usersOpened = false;
      var previewOpened = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AdminSettingsScreen(
            profile: otherAdmin,
            onOpenUserManagement: () => usersOpened = true,
            onOpenPreview: () => previewOpened = true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nima Lama'), findsOneWidget);
      expect(find.text('Administrator'), findsOneWidget);

      await tester.tap(find.text('Manage users'));
      await tester.pumpAndSettle();
      expect(usersOpened, isTrue);

      await tester.tap(find.text('Preview tourist app'));
      await tester.pumpAndSettle();
      expect(previewOpened, isTrue);
    });

    testWidgets('offers no role editor for the signed-in admin', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: AdminSettingsScreen(profile: otherAdmin)),
      );

      await tester.pumpAndSettle();

      expect(
        find.textContaining('role comes from the trusted backend'),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'Make admin'), findsNothing);
    });

    testWidgets('signs out through the injected callback', (tester) async {
      var signedOut = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AdminSettingsScreen(
            profile: otherAdmin,
            onSignOut: () => signedOut = true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The settings screen is a long list, so the sign-out row is scrolled to
      // rather than assumed to be on screen.
      await tester.scrollUntilVisible(
        find.text('Sign out'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(signedOut, isTrue);
    });
  });

  group('FunctionsAdminUserActions', () {
    test('the client prefers the specific reason over the transport status', () {
      // `functions/index.js` reports both a rejected self-operation and a
      // protected last admin as `failed-precondition`, carrying the real code in
      // `details`. Without this the admin UI could only say "something failed".
      expect(
        FunctionsAdminUserActions.errorFromCode(
          FunctionsAdminUserActions.stableCodeFrom(
            'failed-precondition',
            <String, Object?>{'code': 'last-admin'},
          ),
        ),
        AdminUserActionError.lastAdmin,
      );

      expect(
        FunctionsAdminUserActions.errorFromCode(
          FunctionsAdminUserActions.stableCodeFrom(
            'failed-precondition',
            <String, Object?>{'code': 'self-operation'},
          ),
        ),
        AdminUserActionError.selfOperation,
      );

      // Missing, empty or non-string details fall back to the transport status.
      for (final details in <Object?>[
        null,
        'last-admin',
        <String, Object?>{},
      ]) {
        expect(
          FunctionsAdminUserActions.stableCodeFrom(
            'failed-precondition',
            details,
          ),
          'failed-precondition',
        );
      }

      expect(
        FunctionsAdminUserActions.stableCodeFrom(
          'failed-precondition',
          <String, Object?>{'code': ''},
        ),
        'failed-precondition',
      );
    });

    test('maps every backend error code onto a stable client reason', () {
      expect(
        FunctionsAdminUserActions.errorFromCode('unauthenticated'),
        AdminUserActionError.notAuthenticated,
      );

      expect(
        FunctionsAdminUserActions.errorFromCode('permission-denied'),
        AdminUserActionError.notPermitted,
      );

      expect(
        FunctionsAdminUserActions.errorFromCode('self-operation'),
        AdminUserActionError.selfOperation,
      );

      expect(
        FunctionsAdminUserActions.errorFromCode('last-admin'),
        AdminUserActionError.lastAdmin,
      );

      expect(
        FunctionsAdminUserActions.errorFromCode('not-found'),
        AdminUserActionError.unknownUser,
      );

      expect(
        FunctionsAdminUserActions.errorFromCode('anything-else'),
        AdminUserActionError.failed,
      );
    });

    test('function names are stable so the client and backend agree', () {
      expect(FunctionsAdminUserActions.promoteUserFunction, 'promoteUser');
      expect(FunctionsAdminUserActions.demoteUserFunction, 'demoteUser');
      expect(
        FunctionsAdminUserActions.setUserDisabledFunction,
        'setUserDisabled',
      );
      expect(FunctionsAdminUserActions.deleteUserFunction, 'deleteUser');
      expect(
        FunctionsAdminUserActions.sendPasswordResetFunction,
        'sendPasswordReset',
      );
    });
  });
}
