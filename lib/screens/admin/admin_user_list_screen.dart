import 'package:flutter/material.dart';

import '../../services/admin_user_actions.dart';
import '../../services/admin_user_repository.dart';
import '../../services/functions_admin_user_actions.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import 'admin_content_messages.dart';
import 'admin_settings_screen.dart';

/// Administrator view of every registered user, and the only place Yatra
/// changes access.
///
/// Reading the list is plain Firestore through [AdminUserRepository]. Every
/// mutation goes through [AdminUserActions], which calls a callable Cloud
/// Function that re-checks the caller's stored role and applies the
/// lockout safeguards. The client therefore cannot grant itself a role even if
/// the screen is tampered with, and the confirmations below are a convenience
/// rather than the security boundary.
class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({
    super.key,
    this.repository,
    this.actions,
    this.currentUid,
  });

  /// Defaults to [FirestoreAdminUserRepository]. Tests inject a fake.
  final AdminUserRepository? repository;

  /// Defaults to [FunctionsAdminUserActions]. Tests inject a fake.
  final AdminUserActions? actions;

  /// The signed-in administrator, used to hide actions the backend refuses.
  ///
  /// Hiding is only cosmetic: the server rejects self-operations regardless.
  final String? currentUid;

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  /// Resolved lazily so an injected fake is never bypassed.
  late final AdminUserRepository _repository =
      widget.repository ?? FirestoreAdminUserRepository();

  /// Resolved lazily so an injected fake is never bypassed.
  late final AdminUserActions _actions =
      widget.actions ?? FunctionsAdminUserActions();

  List<AdminUserSummary> _users = <AdminUserSummary>[];
  bool _loading = false;
  bool _loadFailed = false;

  /// The uid currently being changed, so only that row shows a spinner and the
  /// action cannot be fired twice.
  String? _busyUid;

  /// Guards against a stale read overwriting a newer one.
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }

    final token = ++_loadToken;

    try {
      final users = await _repository.getUsers();

      if (!mounted || token != _loadToken) return;

      setState(() {
        _users = List<AdminUserSummary>.of(users);
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;

      setState(() {
        _loadFailed = true;
        _loading = false;
      });
    }
  }

  /// Runs a privileged action, showing progress and a friendly result.
  ///
  /// The screen never shows a raw backend error, and it never assumes success:
  /// the list is re-read afterwards so what is displayed is the backend's
  /// truth rather than an optimistic guess.
  Future<void> _run(
    String uid,
    Future<void> Function() action, {
    required String successMessage,
    String? failureMessage,
  }) async {
    if (_busyUid != null) return;

    setState(() {
      _busyUid = uid;
    });

    final messenger = ScaffoldMessenger.of(context);

    try {
      await action();

      if (!mounted) return;

      messenger.showSnackBar(SnackBar(content: Text(successMessage)));

      await _load();
    } catch (error) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(failureMessage ?? adminUserErrorMessageFrom(error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyUid = null;
        });
      }
    }
  }

  /// Confirms a destructive or access-changing action before running it.
  Future<void> _confirm(
    String uid, {
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() action,
    required String successMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _run(uid, action, successMessage: successMessage);
  }

  Future<void> _toggleAdmin(AdminUserSummary user) async {
    if (user.isAdmin) {
      await _confirm(
        user.uid,
        title: 'Remove administrator access?',
        message:
            '${user.displayName} will no longer be able to open the admin '
            'area. You cannot do this if they are the last administrator.',
        confirmLabel: 'Remove access',
        action: () => _actions.demoteUser(user.uid),
        successMessage: '${user.displayName} is no longer an administrator.',
      );

      return;
    }

    await _confirm(
      user.uid,
      title: 'Make an administrator?',
      message:
          '${user.displayName} will be able to open the admin area and manage '
          'users, bookings and the travel catalog.',
      confirmLabel: 'Grant access',
      action: () => _actions.promoteUser(user.uid),
      successMessage: '${user.displayName} is now an administrator.',
    );
  }

  Future<void> _toggleDisabled(AdminUserSummary user) async {
    if (user.disabled) {
      await _confirm(
        user.uid,
        title: 'Re-enable this account?',
        message: '${user.displayName} will be able to sign in again.',
        confirmLabel: 'Re-enable',
        action: () => _actions.setUserDisabled(user.uid, disabled: false),
        successMessage: '${user.displayName} can sign in again.',
      );

      return;
    }

    await _confirm(
      user.uid,
      title: 'Disable this account?',
      message:
          '${user.displayName} will be signed out and blocked from signing in. '
          'Their bookings are kept.',
      confirmLabel: 'Disable',
      action: () => _actions.setUserDisabled(user.uid, disabled: true),
      successMessage: '${user.displayName} has been disabled.',
    );
  }

  Future<void> _delete(AdminUserSummary user) async {
    await _confirm(
      user.uid,
      title: 'Delete this account?',
      message:
          '${user.displayName} will lose access permanently. This cannot be '
          'undone from Yatra.',
      confirmLabel: 'Delete',
      action: () => _actions.deleteUser(user.uid),
      successMessage: '${user.displayName} has been deleted.',
    );
  }

  Future<void> _sendReset(AdminUserSummary user) async {
    await _run(
      user.uid,
      () => _actions.sendPasswordReset(user.uid),
      successMessage:
          'A password reset email has been sent to ${user.displayName}.',
      failureMessage: kAdminPasswordResetFailureMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadFailed && _users.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: AppSpacing.xl),
          YatraEmptyState(
            icon: Icons.cloud_off_outlined,
            message: kAdminUserLoadFailureMessage,
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            child: YatraSecondaryButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: _load,
            ),
          ),
        ],
      );
    }

    if (_users.isEmpty) {
      return const YatraEmptyState(
        icon: Icons.group_outlined,
        message: 'No users yet',
        hint: 'New accounts will appear here.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screen),
      itemCount: _users.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final user = _users[index];

        return _UserCard(
          user: user,
          busy: _busyUid == user.uid,
          blocked: _busyUid != null && _busyUid != user.uid,
          isSelf: user.uid == widget.currentUid,
          onToggleAdmin: () => _toggleAdmin(user),
          onToggleDisabled: () => _toggleDisabled(user),
          onDelete: () => _delete(user),
          onSendReset: () => _sendReset(user),
        );
      },
    );
  }
}

/// One user row with its access controls.
class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.busy,
    required this.blocked,
    required this.isSelf,
    required this.onToggleAdmin,
    required this.onToggleDisabled,
    required this.onDelete,
    required this.onSendReset,
  });

  final AdminUserSummary user;
  final bool busy;
  final bool blocked;
  final bool isSelf;

  final VoidCallback onToggleAdmin;
  final VoidCallback onToggleDisabled;
  final VoidCallback onDelete;
  final VoidCallback onSendReset;

  @override
  Widget build(BuildContext context) {
    // Only the admin's own account and a busy row are locked. A *disabled*
    // account must stay actionable, or there would be no way to re-enable it.
    final disabled = isSelf || blocked;

    final subtitle = <String>[
      if (user.email.isNotEmpty) user.email,
      if (user.touristType != null && user.touristType!.isNotEmpty)
        user.touristType!,
    ].join(' • ');

    return YatraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.displayName, style: AppType.bodyEmphasis),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(subtitle, style: AppType.caption),
                    ],
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.only(left: AppSpacing.sm),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                AdminAccountBadge(
                  isAdmin: user.isAdmin,
                  disabled: user.disabled,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (isSelf)
                // The backend refuses these, so they are not offered at all.
                Text('This is you', style: AppType.caption)
              else ...[
                YatraSecondaryButton(
                  label: user.isAdmin ? 'Remove access' : 'Make admin',
                  icon: user.isAdmin
                      ? Icons.admin_panel_settings_outlined
                      : Icons.shield_outlined,
                  onPressed: disabled ? null : onToggleAdmin,
                ),
                YatraSecondaryButton(
                  label: user.disabled ? 'Re-enable' : 'Disable',
                  icon: user.disabled
                      ? Icons.lock_open_outlined
                      : Icons.lock_outline,
                  onPressed: disabled ? null : onToggleDisabled,
                ),
                YatraSecondaryButton(
                  label: 'Reset password',
                  icon: Icons.mail_outline,
                  onPressed: disabled || user.email.isEmpty
                      ? null
                      : onSendReset,
                ),
                YatraSecondaryButton(
                  label: 'Delete',
                  icon: Icons.delete_outline,
                  onPressed: disabled ? null : onDelete,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
