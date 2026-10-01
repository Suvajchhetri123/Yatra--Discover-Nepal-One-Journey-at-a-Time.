/// Why a privileged user operation failed, in terms the admin UI can show.
///
/// The backend is the only authority on these rules; the client mirrors them
/// for a fast, friendly message but never replaces them.
enum AdminUserActionError {
  /// Nobody is signed in.
  notAuthenticated,

  /// The caller is signed in but is not an admin.
  notPermitted,

  /// The caller tried to change their own account.
  selfOperation,

  /// The operation would leave the application without an admin.
  lastAdmin,

  /// The target user does not exist.
  unknownUser,

  /// Anything else, including backend outages.
  failed,
}

/// A failure from a privileged user operation.
class AdminUserActionException implements Exception {
  const AdminUserActionException(this.error, {this.message});

  final AdminUserActionError error;

  /// Optional backend detail. Never shown to an administrator.
  final String? message;

  @override
  String toString() => 'AdminUserActionException($error)';
}

/// The privileged account operations an administrator can perform.
///
/// These are *not* Firestore writes from the client. Each one calls a callable
/// Cloud Function that re-checks that the caller is an admin, because
/// Firebase Authentication operations (disable, delete, password reset) are
/// impossible to perform safely from a client and a client-side role write
/// would be trivially forgeable.
abstract class AdminUserActions {
  /// Grants `role: admin` to [uid].
  Future<void> promoteUser(String uid);

  /// Returns [uid] to `role: tourist`.
  Future<void> demoteUser(String uid);

  /// Disables or re-enables the Authentication account of [uid].
  Future<void> setUserDisabled(String uid, {required bool disabled});

  /// Deletes the Authentication account and the profile of [uid].
  Future<void> deleteUser(String uid);

  /// Sends a password-reset email to [uid] through Firebase Authentication.
  Future<void> sendPasswordReset(String uid);
}
