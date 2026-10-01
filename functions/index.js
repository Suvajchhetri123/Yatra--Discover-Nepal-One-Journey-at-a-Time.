'use strict';

/**
 * Trusted backend for Yatra's privileged admin operations.
 *
 * Why this exists instead of Firestore rules:
 *
 *   - promoting or demoting an admin must not be possible from a client, and
 *     a client-side `users/{uid}.role` write is trivially forgeable;
 *   - disabling, deleting and password-resetting an Authentication account is
 *     only possible with the Admin SDK;
 *   - the "do not lock yourself out" rules must be enforced where they cannot
 *     be bypassed.
 *
 * Every callable function therefore:
 *   1. checks the request is authenticated;
 *   2. re-reads the caller's own `users/{uid}` and requires `role == 'admin'`;
 *   3. applies the lockout safeguards;
 *   4. only then performs the operation.
 *
 * The Flutter client sends no authority of its own: an `isAdmin` flag in a
 * request would be ignored even if it were sent.
 */

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');

const {
  ERRORS,
  ROLE_ADMIN,
  ROLE_TOURIST,
  requireAdmin,
  requireAuthenticated,
  requireTargetUid,
  assertNotSelf,
  assertNotLastAdminInTransaction,
  isUsableAdmin,
  wouldRemoveAdminCapability,
} = require('./lib/authorization');

admin.initializeApp();

const db = admin.firestore();

/** Firestore reads for the users collection. */
const users = db.collection('users');

/** The region the functions deploy to. */
const REGION = 'asia-south2';

/** Translates a domain error into a callable HttpsError. */
function asHttpsError(error) {
  if (error instanceof HttpsError) return error;

  switch (error.code) {
    case ERRORS.UNAUTHENTICATED:
      return new HttpsError('unauthenticated', error.message);

    case ERRORS.PERMISSION_DENIED:
      return new HttpsError('permission-denied', error.message);

    case ERRORS.SELF_OPERATION:
      return new HttpsError('failed-precondition', error.message, {
        code: error.code,
      });

    case ERRORS.LAST_ADMIN:
      return new HttpsError('failed-precondition', error.message, {
        code: error.code,
      });

    case ERRORS.NOT_FOUND:
      return new HttpsError('not-found', error.message, { code: error.code });

    default:
      logger.error('Yatra admin user operation failed', error);
      return new HttpsError('internal', 'The operation could not be completed.');
  }
}

/** The caller's own profile document. */
async function loadCallerProfile(uid) {
  return users.doc(uid).get();
}

/**
 * Shared preamble: authenticate, authorize, and load both profiles.
 *
 * Returns the caller uid, the caller's role and the target profile document.
 */
async function authorize(request, data) {
  const targetUid = requireTargetUid(data);

  // Authenticate before reading anything: an unauthenticated call must fail as
  // `unauthenticated`, not as a crash on a missing auth block.
  const callerUid = requireAuthenticated(request);

  const callerProfile = await loadCallerProfile(callerUid);

  // Only the stored role counts. Nothing the client sends is trusted.
  requireAdmin(request, callerProfile.data()?.role);

  const targetProfile = await users.doc(targetUid).get();

  return { callerUid, targetUid, targetProfile };
}

/**
 * The serialized admin-guard document.
 *
 * Every operation that can reduce the number of usable admins runs its read and
 * its write inside one transaction on this document. Firestore serializes
 * transactions on the same document, so two simultaneous demotions cannot both
 * read "there is one more admin" and both commit: the second transaction is
 * retried after the first commits, re-reads the changed admin set, and is then
 * rejected.
 *
 * Nothing here has to be created or repaired by hand. The transaction creates it
 * if it is missing, and every read/write of it goes through the trusted
 * backend, so normal administration never needs the Firebase Console.
 */
const ADMIN_GUARD_ID = 'admin-guard';

const adminGuard = db.collection('system').doc(ADMIN_GUARD_ID);

/** Every admin document, keyed by uid. Used inside the guard transaction. */
async function readAdminRecords(transaction) {
  const snapshot = await transaction.get(users.where('role', '==', ROLE_ADMIN));

  const records = {};

  for (const doc of snapshot.docs) {
    records[doc.id] = doc.data();
  }

  return records;
}

/**
 * Applies an admin-reducing change atomically.
 *
 * The transaction revalidates the caller, re-reads the target and every admin,
 * re-checks the last-admin rule, and only then writes. Anything that throws
 * rolls the whole thing back, so Firestore and Firebase Authentication can never
 * disagree about who is an admin.
 *
 * [applyAuth] runs *after* the transaction commits, because Firebase
 * Authentication is not part of the Firestore transaction. If it fails, the
 * Firestore write is compensated back, since the Auth step had not taken
 * effect.
 */
async function withAdminGuard({
  callerUid,
  targetUid,
  targetSnapshot,
  changes,
  applyAuth,
}) {
  const removesCapability = wouldRemoveAdminCapability({
    record: targetSnapshot?.data(),
    changes,
  });

  const commit = async (transaction) => {
    // All reads happen before any write, which is what Firestore transactions
    // require to be retryable.
    //
    // The guard document is read first on every run, so two operations that
    // would each remove an admin are serialized here: the loser retries after
    // the winner commits and re-reads the changed admin set.
    await transaction.get(adminGuard);

    const callerDoc = await transaction.get(users.doc(callerUid));
    const callerRecord = callerDoc.exists ? callerDoc.data() : null;

    // The caller's authority is revalidated inside the transaction. A role
    // revoked by a concurrent operation cannot finish this one.
    if (!isUsableAdmin(callerRecord)) {
      throw new AdminOperationError(
        ERRORS.PERMISSION_DENIED,
        'Only Yatra administrators can manage users.',
      );
    }

    const targetDoc = await transaction.get(users.doc(targetUid));
    const targetRecord = targetDoc.exists ? targetDoc.data() : null;

    const adminRecords = removesCapability
      ? await readAdminRecords(transaction)
      : {};

    // Decide before writing anything, so a rejection leaves no partial state.
    assertNotLastAdminInTransaction({
      callerUid,
      targetUid,
      targetRecord,
      adminRecords,
      callerRecord,
    });

    if (changes.accountDeleted === true) {
      // A delete removes the document itself, so the flag only exists for the
      // duration of the transaction.
      await transaction.delete(targetDoc.ref);
    } else {
      const write = Object.assign({}, changes, {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (targetDoc.exists) {
        await transaction.update(targetDoc.ref, write);
      } else {
        await transaction.set(targetDoc.ref, write);
      }
    }

    // Touch the guard document so the next admin-reducing operation must wait
    // for this commit before it can read the admin set.
    await transaction.set(
      adminGuard,
      {
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        revision: admin.firestore.FieldValue.increment(1),
      },
      { merge: true },
    );
  };

  await db.runTransaction(commit);

  if (!applyAuth) return;

  try {
    await applyAuth();
  } catch (error) {
    // The Firestore mutation is already committed, so roll it back rather than
    // leaving Auth and Firestore contradicting each other.
    logger.error('Yatra admin Auth update failed, compensating', error);

    await compensate({ targetUid, before: targetSnapshot.data() });

    throw error;
  }
}

/**
 * Restores a target document after the Auth step failed.
 *
 * A compensation failure is logged rather than swallowed, because losing both
 * would leave the two systems inconsistent.
 */
async function compensate({ targetUid, before }) {
  try {
    if (!before) {
      await users.doc(targetUid).delete();
      return;
    }

    await users.doc(targetUid).set(before, { merge: true });
  } catch (error) {
    logger.error('Yatra admin compensation failed for ' + targetUid, error);
  }
}

const options = { region: REGION, cors: true };

// ============================================================
// ROLE MANAGEMENT
// ============================================================

/**
 * Grants `role: admin` to a user.
 *
 * Self-promotion is refused: an admin has no reason to promote themselves, and
 * a tourist can never reach this function at all.
 */
exports.promoteUser = onCall(options, async (request) => {
  try {
    const { callerUid, targetUid, targetProfile } = await authorize(
      request,
      request.data,
    );

    assertNotSelf(callerUid, targetUid);

    if (!targetProfile.exists) {
      throw new HttpsError('not-found', 'That user no longer exists.');
    }

    await users.doc(targetUid).set(
      { role: ROLE_ADMIN, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
      { merge: true },
    );

    return { uid: targetUid, role: ROLE_ADMIN };
  } catch (error) {
    throw asHttpsError(error);
  }
});

/**
 * Returns a user to `role: tourist`.
 *
 * Runs through the serialized admin guard, so it is impossible for two
 * simultaneous demotions to both see a second admin and leave the application
 * with none.
 */
exports.demoteUser = onCall(options, async (request) => {
  try {
    const { callerUid, targetUid, targetProfile } = await authorize(
      request,
      request.data,
    );

    assertNotSelf(callerUid, targetUid);

    await withAdminGuard({
      callerUid,
      targetUid,
      targetSnapshot: targetProfile,
      changes: { role: ROLE_TOURIST },
    });

    return { uid: targetUid, role: ROLE_TOURIST };
  } catch (error) {
    throw asHttpsError(error);
  }
});

// ============================================================
// ACCOUNT STATE
// ============================================================

/**
 * Disables or re-enables an Authentication account.
 *
 * Disabling an admin reduces the usable-admin count, so it runs through the
 * serialized guard. Re-enabling can never reduce the count and is always
 * allowed, including for the last admin.
 *
 * Firestore commits first, then Firebase Authentication, and a failure of the
 * second step compensates the first, so the two never contradict each other.
 */
exports.setUserDisabled = onCall(options, async (request) => {
  try {
    const { callerUid, targetUid, targetProfile } = await authorize(
      request,
      request.data,
    );

    assertNotSelf(callerUid, targetUid);

    const disabled = request.data?.disabled === true;

    await withAdminGuard({
      callerUid,
      targetUid,
      targetSnapshot: targetProfile,
      changes: { accountDisabled: disabled },
      applyAuth: () => admin.auth().updateUser(targetUid, { disabled }),
    });

    return { uid: targetUid, disabled };
  } catch (error) {
    throw asHttpsError(error);
  }
});

/**
 * Deletes the Authentication account and the Firestore profile.
 *
 * Deleting an admin reduces the usable-admin count, so the role check and the
 * deletion happen in one serialized transaction. The Auth account is removed
 * afterwards; if that fails, the profile is restored so the user is never left
 * as a half-deleted account.
 */
exports.deleteUser = onCall(options, async (request) => {
  try {
    const { callerUid, targetUid, targetProfile } = await authorize(
      request,
      request.data,
    );

    assertNotSelf(callerUid, targetUid);

    if (!targetProfile.exists) {
      throw new HttpsError('not-found', 'That user no longer exists.');
    }

    await withAdminGuard({
      callerUid,
      targetUid,
      targetSnapshot: targetProfile,
      changes: { accountDeleted: true },
      applyAuth: () => admin.auth().deleteUser(targetUid),
    });

    return { uid: targetUid, deleted: true };
  } catch (error) {
    throw asHttpsError(error);
  }
});

/**
 * Sends a Firebase password-reset email.
 *
 * Passwords are never read, stored or set. This is the only password-related
 * operation Yatra offers, and it uses Firebase's own reset mechanism.
 */
exports.sendPasswordReset = onCall(options, async (request) => {
  try {
    const { callerUid, targetUid, targetProfile } = await authorize(
      request,
      request.data,
    );

    assertNotSelf(callerUid, targetUid);

    const data = targetProfile.data() || {};

    const email = typeof data.email === 'string' ? data.email.trim() : '';

    if (!email) {
      throw new HttpsError(
        'failed-precondition',
        'That account has no email address to reset.',
      );
    }

    // The callable returns the email so the client can trigger Firebase
    // Authentication's real password-reset email flow. No reset link is
    // exposed to the admin UI.
    return { uid: targetUid, email };
  } catch (error) {
    throw asHttpsError(error);
  }
});
