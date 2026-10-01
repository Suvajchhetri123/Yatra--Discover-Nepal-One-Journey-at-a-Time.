/// Shared, user-facing messages for the admin content area (coordinators,
/// places, packages).
///
/// The services deliberately throw technical exceptions; these constants are
/// what the screens show instead, so an admin never sees a stack trace or a
/// Firestore error code.
library;

const String kAdminCatalogLoadFailureMessage =
    'Could not load the travel catalog. Check your connection and try again.';

const String kAdminCatalogSaveFailureMessage =
    'Could not save your changes. Please try again.';

const String kAdminCatalogRequiredFieldsMessage =
    'Please fill in the required fields.';

const String kAdminCatalogInvalidNumberMessage =
    'Enter a valid number of 0 or more.';

const String kAdminCatalogMigrationFailureMessage =
    'Could not migrate the travel catalog. Please try again.';

const String kAdminUserActionFailureMessage =
    'Could not complete that account change. Please try again.';

const String kAdminUserLoadFailureMessage =
    'Could not load users. Please try again.';

const String kAdminPasswordResetFailureMessage =
    'Could not send the password reset email. Please try again.';
