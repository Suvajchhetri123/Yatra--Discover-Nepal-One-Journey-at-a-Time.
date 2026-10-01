'use strict';

/**
 * Tests for the privileged-operation authorization rules.
 *
 * These run with `node --test` and need no Firebase project, emulator or
 * credentials, because the rules are plain functions.
 */

const test = require('node:test');
const assert = require('node:assert');

const {
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
} = require('../lib/authorization');

const requestFor = (uid) => ({ auth: uid ? { uid } : null });

test('requireAdmin rejects a request with no authenticated caller', () => {
  assert.throws(
    () => requireAdmin(requestFor(null), ROLE_ADMIN),
    (error) =>
      error instanceof AdminOperationError &&
      error.code === ERRORS.UNAUTHENTICATED,
  );
});

test('requireAdmin rejects a request with no auth block at all', () => {
  assert.throws(
    () => requireAdmin({}, ROLE_ADMIN),
    (error) => error.code === ERRORS.UNAUTHENTICATED,
  );
});

test('requireAuthenticated returns the uid, and never reads a profile', () => {
  // The backend calls this before any Firestore read, so an unauthenticated
  // caller is rejected as `unauthenticated` rather than crashing on
  // `request.auth.uid`.
  assert.strictEqual(requireAuthenticated(requestFor('admin-1')), 'admin-1');

  assert.throws(
    () => requireAuthenticated(requestFor(null)),
    (error) => error.code === ERRORS.UNAUTHENTICATED,
  );

  assert.throws(
    () => requireAuthenticated({}),
    (error) => error.code === ERRORS.UNAUTHENTICATED,
  );

  assert.throws(
    () => requireAuthenticated(undefined),
    (error) => error.code === ERRORS.UNAUTHENTICATED,
  );
});

test('requireAdmin rejects a signed-in tourist', () => {
  assert.throws(
    () => requireAdmin(requestFor('tourist-1'), ROLE_TOURIST),
    (error) =>
      error instanceof AdminOperationError &&
      error.code === ERRORS.PERMISSION_DENIED,
  );
});

test('requireAdmin rejects a client-supplied isAdmin flag', () => {
  // A caller claiming to be an admin is still refused, because only the stored
  // role is consulted.
  const request = { auth: { uid: 'tourist-1' }, data: { isAdmin: true } };

  assert.throws(
    () => requireAdmin(request, ROLE_TOURIST),
    (error) => error.code === ERRORS.PERMISSION_DENIED,
  );
});

test('requireAdmin accepts a stored admin and returns the caller uid', () => {
  assert.equal(
    requireAdmin(requestFor('admin-1'), ROLE_ADMIN),
    'admin-1',
  );
});

test('requireTargetUid requires a non-empty uid', () => {
  assert.equal(requireTargetUid({ uid: 'user-1' }), 'user-1');
  assert.equal(requireTargetUid({ uid: '  user-1  ' }), 'user-1');

  for (const payload of [undefined, null, {}, { uid: '' }, { uid: '   ' }]) {
    assert.throws(
      () => requireTargetUid(payload),
      (error) => error.code === ERRORS.FAILED,
    );
  }
});

test('a user cannot change their own account', () => {
  assert.throws(
    () => assertNotSelf('admin-1', 'admin-1'),
    (error) => error.code === ERRORS.SELF_OPERATION,
  );
});

test('an admin may act on a different user', () => {
  assert.doesNotThrow(() => assertNotSelf('admin-1', 'user-9'));
});

test('the last remaining admin cannot be demoted', () => {
  assert.throws(
    () =>
      assertNotLastAdmin({
        targetUid: 'admin-1',
        targetRole: ROLE_ADMIN,
        adminUids: ['admin-1'],
      }),
    (error) => error.code === ERRORS.LAST_ADMIN,
  );
});

test('an admin can be demoted while another admin remains', () => {
  assert.doesNotThrow(() =>
    assertNotLastAdmin({
      targetUid: 'admin-2',
      targetRole: ROLE_ADMIN,
      adminUids: ['admin-1', 'admin-2'],
    }),
  );
});

test('a tourist can always be demoted or disabled', () => {
  assert.doesNotThrow(() =>
    assertNotLastAdmin({
      targetUid: 'user-9',
      targetRole: ROLE_TOURIST,
      adminUids: ['admin-1'],
    }),
  );

  assert.doesNotThrow(() =>
    assertNotLastAdmin({
      targetUid: 'user-9',
      targetRole: ROLE_TOURIST,
      adminUids: [],
    }),
  );
});

test('disabling the only usable admin is refused', () => {
  assert.throws(
    () =>
      assertNotLastAdmin({
        targetUid: 'admin-1',
        targetRole: ROLE_ADMIN,
        adminUids: ['admin-1'],
      }),
    (error) => error.code === ERRORS.LAST_ADMIN,
  );
});

test('re-enabling an account never trips the last-admin guard', () => {
  assert.doesNotThrow(() =>
    assertNotLastAdmin({
      targetUid: 'admin-1',
      targetRole: ROLE_ADMIN,
      adminUids: ['admin-1'],
      removesAdminCapability: false,
    }),
  );
});

test('callerUidOf reads the uid or null', () => {
  assert.equal(callerUidOf(requestFor('admin-1')), 'admin-1');
  assert.equal(callerUidOf(requestFor(null)), null);
  assert.equal(callerUidOf(undefined), null);
});

// ============================================================
// USABLE ADMIN AND THE TRANSACTIONAL LAST-ADMIN GUARD
// ============================================================

test('isUsableAdmin requires the admin role and a usable account', () => {
  assert.strictEqual(isUsableAdmin({ role: ROLE_ADMIN }), true);
  assert.strictEqual(isUsableAdmin({ role: ROLE_ADMIN, accountDisabled: true }), false);
  assert.strictEqual(isUsableAdmin({ role: ROLE_ADMIN, accountDeleted: true }), false);
  assert.strictEqual(isUsableAdmin({ role: ROLE_TOURIST }), false);
  assert.strictEqual(isUsableAdmin(null), false);
  assert.strictEqual(isUsableAdmin(undefined), false);

  // An account whose status was never mirrored defaults to usable, so records
  // written before this field existed keep working.
  assert.strictEqual(isUsableAdmin({ role: ROLE_ADMIN, accountDisabled: false }), true);
});

test('wouldRemoveAdminCapability detects every admin-reducing change', () => {
  const admin = { role: ROLE_ADMIN };

  assert.strictEqual(
    wouldRemoveAdminCapability({ record: admin, changes: { role: ROLE_TOURIST } }),
    true,
  );
  assert.strictEqual(
    wouldRemoveAdminCapability({ record: admin, changes: { accountDisabled: true } }),
    true,
  );
  assert.strictEqual(
    wouldRemoveAdminCapability({ record: admin, changes: { accountDeleted: true } }),
    true,
  );

  // These can never reduce the count, so they must not claim to.
  assert.strictEqual(
    wouldRemoveAdminCapability({ record: admin, changes: { accountDisabled: false } }),
    false,
  );
  assert.strictEqual(
    wouldRemoveAdminCapability({ record: admin, changes: { name: 'Renamed' } }),
    false,
  );
  assert.strictEqual(
    wouldRemoveAdminCapability({ record: { role: ROLE_TOURIST }, changes: { accountDeleted: true } }),
    false,
  );
});

test('assertNotLastAdminInTransaction refuses to remove the last usable admin', () => {
  // The registry holds a single usable admin, and it is the target. With
  // self-operations already refused, that leaves nobody able to administer.
  assert.throws(
    () =>
      assertNotLastAdminInTransaction({
        callerUid: 'admin-9',
        targetUid: 'admin-2',
        targetRecord: { role: ROLE_ADMIN },
        adminRecords: { 'admin-2': { role: ROLE_ADMIN } },
      }),
    (error) => error.code === ERRORS.LAST_ADMIN,
  );
});

test('a surviving admin makes the removal legal', () => {
  // The caller keeps their own access, so removing the other admin is fine.
  assert.doesNotThrow(() =>
    assertNotLastAdminInTransaction({
      callerUid: 'admin-1',
      targetUid: 'admin-2',
      targetRecord: { role: ROLE_ADMIN },
      adminRecords: {
        'admin-1': { role: ROLE_ADMIN },
        'admin-2': { role: ROLE_ADMIN },
      },
    }),
  );
});

test('a caller demoted by a concurrent operation cannot finish the removal', () => {
  // This is the branch that actually closes the two-admin race. Two admins each
  // try to demote the other. Whichever commits first wins; the second caller's
  // own role no longer says admin when their transaction re-reads it, so the
  // transaction aborts instead of removing the final admin.
  assert.throws(
    () =>
      assertNotLastAdminInTransaction({
        callerUid: 'admin-2',
        targetUid: 'admin-1',
        targetRecord: { role: ROLE_ADMIN },
        adminRecords: { 'admin-1': { role: ROLE_ADMIN } },
        callerRecord: { role: ROLE_TOURIST },
      }),
    (error) => error.code === ERRORS.PERMISSION_DENIED,
  );

  // A disabled caller is equally unable to continue.
  assert.throws(
    () =>
      assertNotLastAdminInTransaction({
        callerUid: 'admin-2',
        targetUid: 'admin-1',
        targetRecord: { role: ROLE_ADMIN },
        adminRecords: { 'admin-1': { role: ROLE_ADMIN } },
        callerRecord: { role: ROLE_ADMIN, accountDisabled: true },
      }),
    (error) => error.code === ERRORS.PERMISSION_DENIED,
  );
});

test('a still-valid caller passes the revalidation', () => {
  assert.doesNotThrow(() =>
    assertNotLastAdminInTransaction({
      callerUid: 'admin-1',
      targetUid: 'admin-2',
      targetRecord: { role: ROLE_ADMIN },
      adminRecords: {
        'admin-1': { role: ROLE_ADMIN },
        'admin-2': { role: ROLE_ADMIN },
      },
      callerRecord: { role: ROLE_ADMIN },
    }),
  );
});

test('assertNotLastAdminInTransaction allows a removal that leaves an admin', () => {
  const records = {
    'admin-1': { role: ROLE_ADMIN },
    'admin-2': { role: ROLE_ADMIN },
  };

  assert.doesNotThrow(() =>
    assertNotLastAdminInTransaction({
      callerUid: 'admin-1',
      targetUid: 'admin-2',
      targetRecord: { role: ROLE_ADMIN },
      adminRecords: records,
    }),
  );
});

test('a disabled admin does not satisfy the last-admin guarantee', () => {
  // admin-2 is the target and admin-3 is an admin whose account is disabled, so
  // removing admin-2 would leave nobody able to administer. A disabled account
  // must not be counted as a surviving admin.
  const records = {
    'admin-3': { role: ROLE_ADMIN, accountDisabled: true },
  };

  assert.throws(
    () =>
      assertNotLastAdminInTransaction({
        callerUid: 'admin-9',
        targetUid: 'admin-2',
        targetRecord: { role: ROLE_ADMIN },
        adminRecords: records,
      }),
    (error) => error.code === ERRORS.LAST_ADMIN,
  );
});

test('a deleted admin does not satisfy the last-admin guarantee', () => {
  const records = {
    'admin-3': { role: ROLE_ADMIN, accountDeleted: true },
  };

  assert.throws(
    () =>
      assertNotLastAdminInTransaction({
        callerUid: 'admin-9',
        targetUid: 'admin-2',
        targetRecord: { role: ROLE_ADMIN },
        adminRecords: records,
      }),
    (error) => error.code === ERRORS.LAST_ADMIN,
  );
});

test('assertNotLastAdminInTransaction still refuses a self-operation', () => {
  assert.throws(
    () =>
      assertNotLastAdminInTransaction({
        callerUid: 'admin-1',
        targetUid: 'admin-1',
        targetRecord: { role: ROLE_ADMIN },
        adminRecords: { 'admin-1': { role: ROLE_ADMIN }, 'admin-2': { role: ROLE_ADMIN } },
      }),
    (error) => error.code === ERRORS.SELF_OPERATION,
  );
});

test('assertNotLastAdminInTransaction allows acting on a tourist', () => {
  assert.doesNotThrow(() =>
    assertNotLastAdminInTransaction({
      callerUid: 'admin-1',
      targetUid: 'tourist-9',
      targetRecord: { role: ROLE_TOURIST },
      adminRecords: { 'admin-1': { role: ROLE_ADMIN } },
    }),
  );
});

test('assertNotLastAdminInTransaction accepts a Firestore DocumentSnapshot', () => {
  // The backend passes real snapshots, so the helper must read `.data()`.
  const snapshot = { data: () => ({ role: ROLE_ADMIN }) };

  assert.throws(
    () =>
      assertNotLastAdminInTransaction({
        callerUid: 'admin-9',
        targetUid: 'admin-2',
        targetRecord: snapshot,
        adminRecords: { 'admin-2': { role: ROLE_ADMIN } },
      }),
    (error) => error.code === ERRORS.LAST_ADMIN,
  );
});
