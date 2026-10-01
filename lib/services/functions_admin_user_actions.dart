import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_user_actions.dart';
import 'password_reset_service.dart';

/// Invokes a callable Cloud Function and returns its raw response payload.
typedef CallableInvoker =
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> payload,
    );

/// [AdminUserActions] implemented with callable Cloud Functions.
///
/// The Flutter client is not trusted with any part of the decision. Each call
/// is authenticated by Firebase automatically, and the function independently
/// verifies that the caller is an admin and applies the lockout safeguards
/// before touching Firebase Authentication or the `users` collection.
class FunctionsAdminUserActions implements AdminUserActions {
  const FunctionsAdminUserActions({
    this.functions,
    this.auth,
    this.passwordResetService,
    this.callInvoker,
    this.currentUid,
  });

  /// Production leaves these null so the Firebase SDK instances are used.
  /// Tests inject fakes.
  final FirebaseFunctions? functions;
  final FirebaseAuth? auth;
  final PasswordResetService? passwordResetService;

  /// The signed-in uid, from an explicit override or from [auth].
  String? get _currentUid =>
      currentUid ?? (auth ?? FirebaseAuth.instance).currentUser?.uid;

  /// Calls a callable function by name and returns its response payload.
  ///
  /// Production uses Cloud Functions for Firebase. Tests inject a plain function
  /// so they can exercise the real client logic, including error mapping,
  /// without a Firebase project or an emulator.
  final CallableInvoker? callInvoker;

  /// The signed-in uid, or null to ask [auth].
  ///
  /// Supplied directly by tests so no test needs a real Firebase session.
  final String? currentUid;

  /// Callable function names, kept in one place.
  static const String promoteUserFunction = 'promoteUser';
  static const String demoteUserFunction = 'demoteUser';
  static const String setUserDisabledFunction = 'setUserDisabled';
  static const String deleteUserFunction = 'deleteUser';
  static const String sendPasswordResetFunction = 'sendPasswordReset';

  @override
  Future<void> promoteUser(String uid) {
    return _call(promoteUserFunction, {'uid': uid});
  }

  @override
  Future<void> demoteUser(String uid) {
    return _call(demoteUserFunction, {'uid': uid});
  }

  @override
  Future<void> setUserDisabled(String uid, {required bool disabled}) {
    return _call(setUserDisabledFunction, {'uid': uid, 'disabled': disabled});
  }

  @override
  Future<void> deleteUser(String uid) {
    return _call(deleteUserFunction, {'uid': uid});
  }

  @override
  Future<void> sendPasswordReset(String uid) async {
    // The trusted backend authorises the request and enforces the lockout
    // rules. It returns only the target's email address, so the client can ask
    // Firebase Authentication to send its own reset email. No reset link is
    // ever produced here or shown to the admin.
    final result = await _invoke(sendPasswordResetFunction, {'uid': uid});

    final error = result['error'] as String?;

    if (error != null) {
      throw AdminUserActionException(
        errorFromCode(error),
        message: result['message'] as String?,
      );
    }

    final email = result['email'] as String?;

    if (email == null || email.trim().isEmpty) {
      // Without an address there is nothing to send, so this is a failure
      // rather than a silent no-op.
      throw const AdminUserActionException(AdminUserActionError.failed);
    }

    await _passwordResetService.sendPasswordResetEmail(email);
  }

  PasswordResetService get _passwordResetService =>
      passwordResetService ?? const FirebasePasswordResetService();

  /// Calls a function through the injected invoker or Cloud Functions.
  Future<Map<String, dynamic>> _invoke(
    String name,
    Map<String, dynamic> payload,
  ) async {
    final invoker = callInvoker;

    if (invoker != null) return invoker(name, payload);

    final result = await (functions ?? FirebaseFunctions.instance)
        .httpsCallable(name)
        .call(payload);

    return Map<String, dynamic>.of(result.data);
  }

  Future<void> _call(String name, Map<String, dynamic> payload) async {
    if (_currentUid == null) {
      throw const AdminUserActionException(
        AdminUserActionError.notAuthenticated,
      );
    }

    try {
      final result = await _invoke(name, payload);

      final error = result['error'] as String?;

      if (error != null) {
        throw AdminUserActionException(
          errorFromCode(error),
          message: result['message'] as String?,
        );
      }
    } on AdminUserActionException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      throw AdminUserActionException(
        errorFromCode(stableCodeFrom(error.code, error.details)),
        message: error.message,
      );
    } catch (error) {
      throw AdminUserActionException(
        AdminUserActionError.failed,
        message: error.toString(),
      );
    }
  }

  /// Picks the backend's specific reason out of an error, when it sent one.
  ///
  /// The transport status is deliberately coarse: a rejected self-operation and
  /// a protected last admin are both `failed-precondition`, so the exact code
  /// travels in `details`. Reading it is what lets the UI explain the real
  /// reason instead of a generic failure.
  ///
  /// Public so the fallback can be tested directly, for the same reason
  /// [errorFromCode] is public.
  static String stableCodeFrom(String code, [Object? details]) {
    if (details is Map) {
      final specific = details['code'];

      if (specific is String && specific.isNotEmpty) return specific;
    }

    return code;
  }

  /// Maps the backend's stable error codes onto the client enum.
  ///
  /// Public so the mapping can be tested directly: a drift between these codes
  /// and the ones `functions/index.js` returns would otherwise only show up as
  /// a confusing message in the admin UI.
  static AdminUserActionError errorFromCode(String code) {
    switch (code) {
      case 'unauthenticated':
        return AdminUserActionError.notAuthenticated;

      case 'permission-denied':
        return AdminUserActionError.notPermitted;

      case 'self-operation':
        return AdminUserActionError.selfOperation;

      case 'last-admin':
        return AdminUserActionError.lastAdmin;

      case 'not-found':
        return AdminUserActionError.unknownUser;

      default:
        return AdminUserActionError.failed;
    }
  }
}
