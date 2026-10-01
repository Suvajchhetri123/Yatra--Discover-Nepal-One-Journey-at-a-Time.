import 'package:yatra/services/admin_user_actions.dart';
import 'package:yatra/services/admin_user_repository.dart';

/// In-memory [AdminUserRepository] for widget tests.
class FakeAdminUserRepository implements AdminUserRepository {
  FakeAdminUserRepository({List<AdminUserSummary>? users, this.error})
    : users = List<AdminUserSummary>.of(users ?? const []);

  final List<AdminUserSummary> users;

  Object? error;

  int getUsersCalls = 0;

  @override
  Future<List<AdminUserSummary>> getUsers() async {
    getUsersCalls += 1;

    if (error != null) throw error!;

    return List<AdminUserSummary>.of(users);
  }

  @override
  Future<AdminUserSummary?> getUser(String uid) async {
    if (error != null) throw error!;

    for (final user in users) {
      if (user.uid == uid) return user;
    }

    return null;
  }
}

/// Recording [AdminUserActions] that can also be told to fail.
///
/// Every call is recorded so a test can assert *which* privileged operation was
/// attempted, without any test ever performing one.
class FakeAdminUserActions implements AdminUserActions {
  final List<String> calls = <String>[];

  /// Set to make the next (and every following) operation fail.
  AdminUserActionException? failure;

  /// When set, every operation waits on this gate instead of completing.
  ///
  /// Lets a test hold an operation "in flight" and prove that duplicate taps
  /// while it is running do not fire a second privileged call.
  Future<void> Function()? gate;

  @override
  Future<void> promoteUser(String uid) {
    calls.add('promote:$uid');

    return _maybeFail();
  }

  @override
  Future<void> demoteUser(String uid) {
    calls.add('demote:$uid');

    return _maybeFail();
  }

  @override
  Future<void> setUserDisabled(String uid, {required bool disabled}) {
    calls.add('${disabled ? 'disable' : 'enable'}:$uid');

    return _maybeFail();
  }

  @override
  Future<void> deleteUser(String uid) {
    calls.add('delete:$uid');

    return _maybeFail();
  }

  @override
  Future<void> sendPasswordReset(String uid) {
    calls.add('reset:$uid');

    return _maybeFail();
  }

  Future<void> _maybeFail() async {
    final pending = gate;

    if (pending != null) await pending();

    final error = failure;

    if (error != null) throw error;
  }
}
