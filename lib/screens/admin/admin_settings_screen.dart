import 'package:flutter/material.dart';

import '../../services/admin_user_actions.dart';
import '../../services/admin_user_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/yatra_components.dart';
import 'admin_content_messages.dart';

/// Friendly, non-technical copy for the user-management failures.
///
/// The backend is authoritative; the client mirrors the same rules so the
/// administrator gets an explanation instead of a raw error, and so the wording
/// never promises something the server would refuse.
String adminUserErrorMessage(AdminUserActionError error) {
  switch (error) {
    case AdminUserActionError.notAuthenticated:
      return 'Your session has expired. Sign in again to continue.';

    case AdminUserActionError.notPermitted:
      return 'Only Yatra administrators can manage users.';

    case AdminUserActionError.selfOperation:
      return 'You cannot change your own account from this screen.';

    case AdminUserActionError.lastAdmin:
      return 'That is the last administrator. Promote someone else first.';

    case AdminUserActionError.unknownUser:
      return 'That user no longer exists.';

    case AdminUserActionError.failed:
      // A failed password reset is the most common specific failure here.
      // The caller may want to distinguish, but for the generic mapper we
      // keep the safe default.
      return kAdminUserActionFailureMessage;
  }
}

/// Turns any thrown object into the copy above, defaulting to a safe message.
///
/// A raw backend string is never shown, so an internal error cannot leak a
/// field name or a stack trace into the admin UI.
String adminUserErrorMessageFrom(Object error) {
  if (error is AdminUserActionException) {
    return adminUserErrorMessage(error.error);
  }

  return kAdminUserActionFailureMessage;
}

/// Administrative view of the signed-in admin's own account and app access.
///
/// It deliberately does not offer a role editor: the one thing this screen must
/// not do is let an admin change their own role from the client, which the
/// backend refuses anyway.
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({
    super.key,
    required this.profile,
    this.onOpenUserManagement,
    this.onOpenPreview,
    this.onSignOut,
  });

  /// The signed-in administrator, resolved by the caller.
  final AdminUserSummary? profile;

  final VoidCallback? onOpenUserManagement;
  final VoidCallback? onOpenPreview;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final admin = profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          YatraSectionTitle(
            title: 'Signed in',
            subtitle: 'Your administrator account.',
          ),
          const SizedBox(height: AppSpacing.md),
          YatraCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  admin?.displayName.isNotEmpty == true
                      ? admin!.displayName
                      : 'Administrator',
                  style: AppType.bodyEmphasis,
                ),
                if (admin != null && admin.email.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(admin.email, style: AppType.caption),
                ],
                const SizedBox(height: AppSpacing.md),
                const AdminAccountBadge(isAdmin: true),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your role comes from the trusted backend. It cannot be '
                  'edited here, and no other admin can remove you while you are '
                  'signed in.',
                  style: AppType.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          YatraSectionTitle(
            title: 'People and access',
            subtitle: 'Grant or revoke administrator access from Yatra.',
          ),
          const SizedBox(height: AppSpacing.md),
          YatraCard(
            onTap: onOpenUserManagement,
            child: const Row(
              children: [
                Icon(Icons.group_outlined, color: AppColors.primary),
                SizedBox(width: AppSpacing.md),
                Expanded(child: Text('Manage users')),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          YatraSectionTitle(
            title: 'Tourist experience',
            subtitle: 'Check the app exactly as a traveller sees it.',
          ),
          const SizedBox(height: AppSpacing.md),
          YatraCard(
            onTap: onOpenPreview,
            child: const Row(
              children: [
                Icon(Icons.visibility_outlined, color: AppColors.primary),
                SizedBox(width: AppSpacing.md),
                Expanded(child: Text('Preview tourist app')),
                Icon(Icons.chevron_right),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Preview uses your administrator session, so anything that would '
            'create real data stays switched off.',
            style: AppType.caption,
          ),
          const SizedBox(height: AppSpacing.xl),

          YatraSecondaryButton(
            label: 'Sign out',
            icon: Icons.logout,
            onPressed: onSignOut,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Yatra administrator console',
            textAlign: TextAlign.center,
            style: AppType.caption,
          ),
        ],
      ),
    );
  }
}

/// Status pill shown on a user: administrator or traveller, and whether the
/// trusted backend has disabled the account.
class AdminAccountBadge extends StatelessWidget {
  const AdminAccountBadge({
    super.key,
    required this.isAdmin,
    this.disabled = false,
  });

  final bool isAdmin;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final label = disabled
        ? 'Account disabled'
        : (isAdmin ? 'Administrator' : 'Traveller');

    final color = disabled
        ? AppColors.danger
        : (isAdmin ? AppColors.primary : AppColors.success);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: AppType.caption.copyWith(color: color)),
    );
  }
}
