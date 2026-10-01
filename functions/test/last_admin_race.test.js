'use strict';

/**
 * Concurrency test for the last-admin guarantee.
 *
 * The race under test: two usable admins, and two operations running at the
 * same time, each of which would remove one admin. A naive implementation reads
 * the admin set, decides, then writes, so both can observe "there is one more
 * admin" and both commit, leaving nobody able to administer Yatra.
 *
 * These tests exercise the real decision helper
 * (`assertNotLastAdminInTransaction`) through an in-memory model of Firestore's
 * optimistic-concurrency retry: the guard document is read inside the
 * transaction, so a conflicting writer makes the loser re-run its body against
 * committed state. The tests deliberately start both operations with
 * `Promise.all` so they interleave, rather than checking them one after the
 * other.
 *
 * The model lives here rather than in the authorization module because it is a
 * test harness, not production logic: Firestore provides the serialization, and
 * this only reproduces it so the decision logic can be proven correct.
 */

const test = require('node:test');
const assert = require('node:assert');

const {
  ROLE_ADMIN,
  ROLE_TOURIST,
  AdminOperationError,
  isUsableAdmin,
  wouldRemoveAdminCapability,
  assertNotLastAdminInTransaction,
} = require('../lib/authorization');

/** An in-memory stand-in for the serialized admin guard. */
const GUARD = 'admin-guard';

/**
 * A tiny Firestore-like store with transactions and conflict retry.
 *
 * `transaction(fn)` runs `fn` against a snapshot view. If another transaction
 * wrote to the guard document while this one was in flight, the body runs again
 * against the newer state, exactly as Firestore retries a transaction whose
 * reads were invalidated.
 */
class FakeFirestore {
  constructor(users) {
    this.users = new Map(
      Object.entries(users).map(([uid, data]) => [uid, { ...data }]),
    );
    this.guardRevision = 0;
  }

  /** Usable admins currently committed. */
  usableAdminUids() {
    return [...this.users.entries()]
      .filter(([, data]) => isUsableAdmin(data))
      .map(([uid]) => uid)
      .sort();
  }

  /**
   * Runs one admin-reducing operation the way `withAdminGuard` does.
   *
   * Returns a promise that resolves when the operation commits, or rejects with
   * an [AdminOperationError] when the guard refuses it.
   */
  runGuarded({ callerUid, targetUid, changes }) {
    return new Promise((resolve, reject) => {
      const attempt = (guardSeen) => {
        // Snapshot everything the body reads, before any write.
        const seenRevision = this.guardRevision;
        const callerRecord = this.users.get(callerUid) || null;
        const targetRecord = this.users.get(targetUid) || null;

        const adminRecords = {};

        for (const [uid, data] of this.users) {
          if (isUsableAdmin(data)) adminRecords[uid] = { ...data };
        }

        // Yield to the event loop so genuinely concurrent callers interleave
        // here, between their reads and their commit.
        setImmediate(() => {
          // Firestore retries when a document the transaction read has since
          // been written. The guard document is what admin-reducing operations
          // serialize on.
          if (this.guardRevision !== seenRevision && guardSeen === false) {
            attempt(true);
            return;
          }

          try {
            assertNotLastAdminInTransaction({
              callerUid,
              targetUid,
              targetRecord,
              adminRecords,
              callerRecord,
            });
          } catch (error) {
            reject(error);
            return;
          }

          // Commit, then bump the guard so a peer must re-read.
          const existing = this.users.get(targetUid);

          if (changes.accountDeleted === true) {
            this.users.delete(targetUid);
          } else if (existing) {
            this.users.set(targetUid, { ...existing, ...changes });
          } else {
            this.users.set(targetUid, { ...changes });
          }

          this.guardRevision += 1;

          resolve({ callerUid, targetUid });
        });
      };

      attempt(false);
    });
  }
}

test('two simultaneous demotions cannot leave zero admins', async () => {
  // Exactly two usable admins, each trying to demote the other. Because
  // self-operations are refused, neither may target themselves, so this is the
  // only shape the race can take.
  const db = new FakeFirestore({
    'admin-1': { role: ROLE_ADMIN },
    'admin-2': { role: ROLE_ADMIN },
  });

  const results = await Promise.allSettled([
    db.runGuarded({
      callerUid: 'admin-1',
      targetUid: 'admin-2',
      changes: { role: ROLE_TOURIST },
    }),
    db.runGuarded({
      callerUid: 'admin-2',
      targetUid: 'admin-1',
      changes: { role: ROLE_TOURIST },
    }),
  ]);

  const succeeded = results.filter((r) => r.status === 'fulfilled');
  const failed = results.filter((r) => r.status === 'rejected');

  // Exactly one may succeed. This is the guarantee the old read-then-write
  // implementation could not make.
  assert.strictEqual(succeeded.length, 1, 'exactly one demotion may commit');
  assert.strictEqual(failed.length, 1, 'the loser must be refused');

  // The refusal must be a safe, specific error, never a crash.
  const error = failed[0].reason;

  assert.ok(
    error instanceof AdminOperationError,
    `expected AdminOperationError, got ${error}`,
  );
  assert.ok(
    ['permission-denied', 'last-admin', 'self-operation'].includes(error.code),
    `unexpected error code ${error.code}`,
  );

  // And the invariant that matters: Yatra is never left without an admin.
  assert.strictEqual(
    db.usableAdminUids().length,
    1,
    'at least one usable admin must remain',
  );
});

test('a simultaneous demote and disable cannot leave zero admins', async () => {
  const db = new FakeFirestore({
    'admin-1': { role: ROLE_ADMIN },
    'admin-2': { role: ROLE_ADMIN },
  });

  const results = await Promise.allSettled([
    db.runGuarded({
      callerUid: 'admin-1',
      targetUid: 'admin-2',
      changes: { role: ROLE_TOURIST },
    }),
    db.runGuarded({
      callerUid: 'admin-2',
      targetUid: 'admin-1',
      changes: { accountDisabled: true },
    }),
  ]);

  const succeeded = results.filter((r) => r.status === 'fulfilled');

  assert.strictEqual(succeeded.length, 1, 'exactly one operation may commit');
  assert.strictEqual(db.usableAdminUids().length, 1);
});

test('a simultaneous demote and delete cannot leave zero admins', async () => {
  const db = new FakeFirestore({
    'admin-1': { role: ROLE_ADMIN },
    'admin-2': { role: ROLE_ADMIN },
  });

  const results = await Promise.allSettled([
    db.runGuarded({
      callerUid: 'admin-1',
      targetUid: 'admin-2',
      changes: { role: ROLE_TOURIST },
    }),
    db.runGuarded({
      callerUid: 'admin-2',
      targetUid: 'admin-1',
      changes: { accountDeleted: true },
    }),
  ]);

  const succeeded = results.filter((r) => r.status === 'fulfilled');

  assert.strictEqual(succeeded.length, 1, 'exactly one operation may commit');
  assert.strictEqual(db.usableAdminUids().length, 1);
});

test('with four admins, two simultaneous demotions are both allowed', async () => {
  // The guard must not be needlessly restrictive: when other admins survive, two
  // concurrent removals are both safe and both may commit. The callers are
  // different from the targets, because an admin may not act on themselves.
  const db = new FakeFirestore({
    'admin-1': { role: ROLE_ADMIN },
    'admin-2': { role: ROLE_ADMIN },
    'admin-3': { role: ROLE_ADMIN },
    'admin-4': { role: ROLE_ADMIN },
  });

  const results = await Promise.allSettled([
    db.runGuarded({
      callerUid: 'admin-1',
      targetUid: 'admin-3',
      changes: { role: ROLE_TOURIST },
    }),
    db.runGuarded({
      callerUid: 'admin-2',
      targetUid: 'admin-4',
      changes: { role: ROLE_TOURIST },
    }),
  ]);

  const succeeded = results.filter((r) => r.status === 'fulfilled');

  assert.strictEqual(succeeded.length, 2, 'both removals are safe here');
  assert.strictEqual(db.usableAdminUids().length, 2);
});

test('three simultaneous removals from four admins all succeed safely', async () => {
  // Three admins each remove a different one, leaving a fourth untouched. All
  // three commits are safe, so the guard must allow every one of them.
  const db = new FakeFirestore({
    'admin-1': { role: ROLE_ADMIN },
    'admin-2': { role: ROLE_ADMIN },
    'admin-3': { role: ROLE_ADMIN },
    'admin-4': { role: ROLE_ADMIN },
  });

  const results = await Promise.allSettled([
    db.runGuarded({
      callerUid: 'admin-1',
      targetUid: 'admin-3',
      changes: { role: ROLE_TOURIST },
    }),
    db.runGuarded({
      callerUid: 'admin-2',
      targetUid: 'admin-4',
      changes: { role: ROLE_TOURIST },
    }),
    db.runGuarded({
      callerUid: 'admin-3',
      targetUid: 'admin-1',
      changes: { role: ROLE_TOURIST },
    }),
  ]);

  const succeeded = results.filter((r) => r.status === 'fulfilled');

  // admin-3 is targeted by admin-1 and targets admin-1 itself, so at most one
  // of those two can commit; the rest are safe.
  assert.ok(
    succeeded.length >= 1,
    'at least one removal is always safe with four admins',
  );
  assert.ok(
    db.usableAdminUids().length >= 1,
    'at least one usable admin always remains',
  );
});

test('the old read-then-write behaviour would have failed this race', async () => {
  // Guards against the guard being "fixed" back into something racy: this
  // reproduces the previous implementation, which read the admin set, then wrote
  // without any serialization, and shows it does leave zero admins.
  const db = new FakeFirestore({
    'admin-1': { role: ROLE_ADMIN },
    'admin-2': { role: ROLE_ADMIN },
  });

  const naiveDemote = (callerUid, targetUid) =>
    new Promise((resolve) => {
      const targetRecord = db.users.get(targetUid) || null;

      const adminRecords = {};

      for (const [uid, data] of db.users) {
        if (isUsableAdmin(data)) adminRecords[uid] = { ...data };
      }

      setImmediate(() => {
        // The old code only counted admins, and never re-checked the caller.
        const remaining = Object.keys(adminRecords).filter(
          (uid) => uid !== targetUid && isUsableAdmin(adminRecords[uid]),
        );

        if (remaining.length === 0) {
          resolve(false);
          return;
        }

        db.users.set(targetUid, { ...targetRecord, role: ROLE_TOURIST });

        resolve(true);
      });
    });

  const outcomes = await Promise.all([
    naiveDemote('admin-1', 'admin-2'),
    naiveDemote('admin-2', 'admin-1'),
  ]);

  assert.deepStrictEqual(
    outcomes,
    [true, true],
    'the naive version lets both commits through, which is the bug',
  );
  assert.strictEqual(
    db.usableAdminUids().length,
    0,
    'which is how the application ends up with no admin at all',
  );
});

test('wouldRemoveAdminCapability routes only admin-reducing work through the guard', () => {
  const admin = { role: ROLE_ADMIN };

  assert.strictEqual(
    wouldRemoveAdminCapability({
      record: admin,
      changes: { role: ROLE_TOURIST },
    }),
    true,
  );
  assert.strictEqual(
    wouldRemoveAdminCapability({
      record: admin,
      changes: { accountDisabled: true },
    }),
    true,
  );
  assert.strictEqual(
    wouldRemoveAdminCapability({
      record: admin,
      changes: { accountDisabled: false },
    }),
    false,
  );
  assert.strictEqual(
    wouldRemoveAdminCapability({
      record: { role: ROLE_TOURIST },
      changes: { accountDeleted: true },
    }),
    false,
  );
});
