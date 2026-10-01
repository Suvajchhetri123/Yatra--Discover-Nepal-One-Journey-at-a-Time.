'use strict';

/**
 * Authorization and lockout rules for the privileged user operations.
 *
 * This module is intentionally free of any Firebase import so the rules can be
 * unit tested with `node --test`, with no emulator and no credentials. The
 * callable functions in `index.js` supply the real Firestore/Auth calls and
 * delegate every decision to these pure functions.
 */

/** Stable error codes shared with the Flutter client. */
const ERRORS = {
  UNAUTHENTICATED: 'unauthenticated',
  PERMISSION_DENIED: 'permission-denied',
  SELF_OPERATION: 'self-operation',
  LAST_ADMIN: 'last-admin',
  NOT_FOUND: 'not-found',
  FAILED: 'failed',
};

const ROLE_ADMIN = 'admin';
const ROLE_TOURIST = 'tourist';

/** An error that a callable function may return to the client. */
class AdminOperationError extends Error {
  constructor(code, message) {
    super(message || code);
    this.code = code;
    this.name = 'AdminOperationError';
  }
}

/**
 * Confirms the caller is an authenticated admin.
 *
 * `request` is the callable request. `role` is the caller's stored role, which
 * only the trusted backend may read. A client-supplied `isAdmin` flag is never
 * consulted, because a client can send anything.
 */
function requireAuthenticated(request) {
  if (!request || !request.auth || !request.auth.uid) {
    throw new AdminOperationError(
      ERRORS.UNAUTHENTICATED,
      'Sign in before managing users.',
    );
  }

  return request.auth.uid;
}

function requireAdmin(request, role) {
  requireAuthenticated(request);

  if (role !== ROLE_ADMIN) {
    throw new AdminOperationError(
      ERRORS.PERMISSION_DENIED,
      'Only Yatra administrators can manage users.',
    );
  }

  return request.auth.uid;
}

/** The uid an operation was asked to act on. */
function requireTargetUid(data) {
  const uid = data && typeof data.uid === 'string' ? data.uid.trim() : '';

  if (!uid) {
    throw new AdminOperationError(
      ERRORS.FAILED,
      'A user must be selected.',
    );
  }

  return uid;
}

/**
 * Guards the operations that would lock an administrator out of Yatra.
 *
 * Blocked for every caller:
 *   - promoting yourself, so a tourist can never self-promote;
 *   - demoting, disabling or deleting yourself;
 *   - demoting, disabling or deleting the only remaining admin.
 */
function assertNotSelf(callerUid, targetUid) {
  if (callerUid === targetUid) {
    throw new AdminOperationError(
      ERRORS.SELF_OPERATION,
      'You cannot change your own account from here.',
    );
  }
}

/**
 * Keeps at least one usable admin.
 *
 * `adminUids` must be every uid that is an admin *with a usable account* (the
 * caller builds it that way, so a disabled admin does not count). The check
 * only applies when the operation actually removes the target's ability to
 * administer: re-enabling an account, or acting on a tourist, is always fine.
 */
function assertNotLastAdmin({
  targetUid,
  targetRole,
  adminUids,
  removesAdminCapability = true,
}) {
  if (!removesAdminCapability) return;

  // A tourist can never be the last admin.
  if (targetRole !== ROLE_ADMIN) return;

  const remaining = (adminUids || []).filter(
    (uid) => uid !== targetUid && uid !== undefined && uid !== null,
  );

  if (remaining.length === 0) {
    throw new AdminOperationError(
      ERRORS.LAST_ADMIN,
      'This is the last administrator. Promote someone else first.',
    );
  }
}

/** A user document, reduced to the fields the lockout decision depends on. */
function isUsableAdmin(record) {
  if (!record || typeof record !== 'object') return false;

  if (record.role !== ROLE_ADMIN) return false;

  // A disabled or deleted Authentication account cannot administer, so it must
  // not be allowed to satisfy the last-admin guarantee. An account whose status
  // has simply never been mirrored defaults to usable, so existing records
  // behave exactly as they did before this field existed.
  if (record.accountDisabled === true) return false;

  if (record.accountDeleted === true) return false;

  return true;
}

/**
 * Keeps at least one usable admin, evaluated from documents read inside the
 * same transaction as the write.
 *
 * This is the decision half of the guard. The caller must read every admin
 * document and pass them here *within* the transaction, and must abort the
 * transaction if this throws. Because Firestore re-runs a transaction whose
 * reads changed, two simultaneous demotions cannot both observe a second admin
 * and both commit: the second one re-reads the first one's write and is
 * rejected here.
 *
 * `adminRecords` maps uid to that user's stored document.
 */
function assertNotLastAdminInTransaction({
  callerUid,
  targetUid,
  targetRecord,
  adminRecords,
  callerRecord,
}) {
  assertNotSelf(callerUid, targetUid);

  const record =
    targetRecord && targetRecord.data ? targetRecord.data() : targetRecord;

  // Acting on a tourist, or making an unusable account usable again, can never
  // reduce the number of usable admins.
  if (!isUsableAdmin(record)) return;

  // The caller is revalidated inside the transaction. This is the branch that
  // actually stops the two-admin race: if a concurrent operation already demoted
  // the caller, they are no longer allowed to finish removing the other admin.
  if (callerRecord !== undefined) {
    const caller =
      callerRecord && callerRecord.data
        ? callerRecord.data()
        : callerRecord;

    if (!isUsableAdmin(caller)) {
      throw new AdminOperationError(
        ERRORS.PERMISSION_DENIED,
        'Only Yatra administrators can manage users.',
      );
    }
  }

  // Count the usable admins that would survive this operation. The caller is
  // included, because self-operations are already refused above.
  const remaining = Object.keys(adminRecords || {}).filter(
    (uid) => uid !== targetUid && isUsableAdmin(adminRecords[uid]),
  );

  if (remaining.length === 0) {
    throw new AdminOperationError(
      ERRORS.LAST_ADMIN,
      'This is the last administrator. Promote someone else first.',
    );
  }
}

/**
 * Whether applying [changes] would turn a currently-usable admin into an
 * unusable one.
 *
 * Used to decide if a mutation has to run through the serialized admin-guard
 * transaction at all, so re-enabling an account and promoting a tourist stay
 * cheap and never contend on the guard document.
 */
function wouldRemoveAdminCapability({ record, changes }) {
  if (!isUsableAdmin(record)) return false;

  const next = Object.assign({}, record, changes || {});

  // Anything that changes role away from admin, or makes the account unusable.
  if (next.role !== ROLE_ADMIN) return true;

  if (next.accountDisabled === true) return true;

  if (next.accountDeleted === true) return true;

  return false;
}

/** Reads the uid of a data payload, tolerating missing input. */
function callerUidOf(request) {
  return request && request.auth ? request.auth.uid : null;
}

module.exports = {
  ERRORS,
  ROLE_ADMIN,
  ROLE_TOURIST,
  AdminOperationError,
  requireAdmin,
  requireAuthenticated,
  requireTargetUid,
  assertNotSelf,
  assertNotLastAdmin,
  assertNotLastAdminInTransaction,
  isUsableAdmin,
  wouldRemoveAdminCapability,
  callerUidOf,
};
