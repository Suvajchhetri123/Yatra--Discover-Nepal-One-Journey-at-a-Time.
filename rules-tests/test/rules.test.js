'use strict';

/**
 * Behaviour tests for the Yatra Security Rules.
 *
 * These run against the Firebase emulators and are the only place where the
 * claim "only an admin may change this" is actually verified. The Flutter
 * tests cannot cover it: the client is not the boundary, the rules are.
 *
 * Run with:
 *   npm test
 * from the rules-tests directory.
 */

const test = require('node:test');
const assert = require('node:assert');

const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

const { doc, setDoc, getDoc, deleteDoc } = require('firebase/firestore');
const { ref, uploadBytes, getBytes, deleteObject } = require('firebase/storage');

const PROJECT_ID = 'yatra-demo';

const ADMIN_UID = 'admin-1';
const TOURIST_UID = 'tourist-1';
const OTHER_ADMIN_UID = 'admin-2';

let testEnv;

/** Seeded once, because rules are evaluated per request against real data. */
const IMAGE_BYTES = new Uint8Array([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49,
  0x48, 0x44, 0x52,
]);

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: require('node:fs').readFileSync('../firestore.rules', 'utf8'),
    },
    storage: {
      rules: require('node:fs').readFileSync('../storage.rules', 'utf8'),
    },
  });

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    await setDoc(doc(db, 'users', ADMIN_UID), {
      name: 'Root Admin',
      email: 'admin@yatra.test',
      role: 'admin',
    });

    await setDoc(doc(db, 'users', OTHER_ADMIN_UID), {
      name: 'Second Admin',
      email: 'admin2@yatra.test',
      role: 'admin',
    });

    await setDoc(doc(db, 'users', TOURIST_UID), {
      name: 'Asha Rai',
      email: 'asha@yatra.test',
      role: 'tourist',
      touristType: 'adventurer',
    });

    // Seeded with a complete document, because the rules reject partial ones.
    await setDoc(doc(db, 'places', 'mustang-muktinath'), {
      name: 'Muktinath',
      location: 'Mustang',
      entryFee: 300,
      active: true,
      imageUrls: ['places/mustang-muktinath/one.jpg'],
    });

    // The referenced photo, so reads and deletes have something real to act on.
    await uploadBytes(
      ref(context.storage(), 'places/mustang-muktinath/one.jpg'),
      imageBytes,
      { contentType: 'image/jpeg' },
    );

    await setDoc(doc(db, 'bookings', 'booking-1'), {
      userId: TOURIST_UID,
      status: 'pending',
    });
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

const asUser = (uid) => testEnv.authenticatedContext(uid).firestore();
const asUserStorage = (uid) => testEnv.authenticatedContext(uid).storage();
const asAnonymous = () => testEnv.unauthenticatedContext().firestore();
const asAnonymousStorage = () => testEnv.unauthenticatedContext().storage();

/** A tiny PNG, so the content-type rule is satisfied honestly. */
const imageBytes = IMAGE_BYTES;

const NOT_AN_IMAGE = new Uint8Array([0x25, 0x50, 0x44, 0x46]); // "%PDF"

test('Firestore: a signed-out visitor can read nothing', async () => {
  const db = asAnonymous();

  await assertFails(getDoc(doc(db, 'users', TOURIST_UID)));
  await assertFails(getDoc(doc(db, 'places', 'mustang-muktinath')));
});

test('Firestore: an admin may manage the catalog', async () => {
  const db = asUser(ADMIN_UID);

  await assertSucceeds(
    setDoc(doc(db, 'places', 'pokhara-phewa'), {
      name: 'Phewa Lake',
      location: 'Pokhara',
      entryFee: 0,
      active: true,
    }),
  );

  await assertSucceeds(
    setDoc(doc(db, 'coordinators', 'c-1'), {
      name: 'Asha Rai',
      phone: '9800000000',
      email: 'asha@yatra.test',
      active: true,
    }),
  );

  await assertSucceeds(
    setDoc(doc(db, 'packages', 'pkg-1'), {
      title: 'Escape',
      region: 'Baglung',
      price: 12000,
      durationDays: 5,
      active: true,
    }),
  );

  // A partial document is rejected even for an admin, so a broken record can
  // never reach the registry the tourist app reads.
  await assertFails(
    setDoc(doc(db, 'places', 'pokhara-partial'), { name: 'No Fee' }),
  );
});

test('Firestore: a tourist may not write to the catalog', async () => {
  const db = asUser(TOURIST_UID);

  await assertFails(
    setDoc(doc(db, 'places', 'pokhara-side'), { name: 'Tamche' }),
  );
});

test('Firestore: no client may write the admin guard document', async () => {
  // The serialized last-admin guard is server state. A client that could write
  // it could interfere with the lockout protection.
  const db = asUser(ADMIN_UID);

  await assertFails(setDoc(doc(db, 'system', 'admin-guard'), { revision: 99 }));
  await assertFails(deleteDoc(doc(db, 'system', 'admin-guard')));
  await assertFails(getDoc(doc(db, 'system', 'admin-guard')));
  await assertFails(setDoc(doc(asAnonymous(), 'system', 'admin-guard'), { revision: 1 }));
});

test('Firestore: no client may set accountDisabled or accountDeleted', async () => {
  // These two fields mirror Firebase Authentication status. They decide whether
  // an admin counts as "usable", so a client write would let an admin fake
  // their way past the last-admin protection.
  const db = asUser(ADMIN_UID);

  await assertFails(
    setDoc(doc(db, 'users', TOURIST_UID), { accountDisabled: true }),
  );

  await assertFails(
    setDoc(doc(db, 'users', TOURIST_UID), { accountDeleted: true }),
  );
});

test('Firestore: a tourist may not promote themselves', async () => {
  const db = asUser(TOURIST_UID);

  // The field is not updatable by anyone, which is what forces role changes
  // through the trusted backend.
  await assertFails(
    setDoc(doc(db, 'users', TOURIST_UID), { role: 'admin' }),
  );

  await assertFails(setDoc(doc(db, 'users', ADMIN_UID), { role: 'admin' }));
});

test('Firestore: no client may delete anything', async () => {
  const db = asUser(ADMIN_UID);

  await assertFails(deleteDoc(doc(db, 'places', 'mustang-muktinath')));
  await assertFails(deleteDoc(doc(db, 'bookings', 'booking-1')));
  await assertFails(deleteDoc(doc(db, 'users', TOURIST_UID)));
});

test('Firestore: removal is a soft deactivation only', async () => {
  const db = asUser(ADMIN_UID);

  await assertSucceeds(
    setDoc(doc(db, 'places', 'mustang-muktinath'), { active: false }, { merge: true }),
  );
});

test('Firestore: a tourist reads only their own bookings', async () => {
  const db = asUser(TOURIST_UID);

  await assertSucceeds(getDoc(doc(db, 'bookings', 'booking-1')));
});

test('Storage: a signed-out visitor cannot read place photos', async () => {
  const storage = asAnonymousStorage();

  await assertFails(
    getBytes(ref(storage, 'places/mustang-muktinath/one.jpg')),
  );
});

test('Storage: a signed-in user may read a place photo', async () => {
  const storage = asUserStorage(TOURIST_UID);

  await assertSucceeds(
    getBytes(ref(storage, 'places/mustang-muktinath/one.jpg')),
  );
});

test('Storage: only an admin may upload a photo', async () => {
  await assertSucceeds(
    uploadBytes(
      ref(asUserStorage(ADMIN_UID), 'places/mustang-muktinath/admin.jpg'),
      imageBytes,
      { contentType: 'image/jpeg' },
    ),
  );

  await assertFails(
    uploadBytes(
      ref(asUserStorage(TOURIST_UID), 'places/mustang-muktinath/tourist.jpg'),
      imageBytes,
      { contentType: 'image/jpeg' },
    ),
  );

  await assertFails(
    uploadBytes(
      ref(asAnonymousStorage(), 'places/mustang-muktinath/anon.jpg'),
      imageBytes,
      { contentType: 'image/jpeg' },
    ),
  );
});

test('Storage: a non-image cannot be uploaded even by an admin', async () => {
  await assertFails(
    uploadBytes(
      ref(asUserStorage(ADMIN_UID), 'places/mustang-muktinath/payload.pdf'),
      NOT_AN_IMAGE,
      { contentType: 'application/pdf' },
    ),
  );
});

test('Storage: an oversized photo is refused', async () => {
  const tooBig = new Uint8Array(5 * 1024 * 1024 + 1);

  await assertFails(
    uploadBytes(
      ref(asUserStorage(ADMIN_UID), 'places/mustang-muktinath/huge.jpg'),
      tooBig,
      { contentType: 'image/jpeg' },
    ),
  );
});

test('Storage: only an admin may delete a photo', async () => {
  await assertFails(
    deleteObject(ref(asUserStorage(TOURIST_UID), 'places/mustang-muktinath/admin.jpg')),
  );

  await assertSucceeds(
    deleteObject(ref(asUserStorage(ADMIN_UID), 'places/mustang-muktinath/admin.jpg')),
  );
});

test('Storage: every other bucket path is closed to clients', async () => {
  const storage = asUserStorage(ADMIN_UID);

  await assertFails(uploadBytes(ref(storage, 'users/avatar.jpg'), imageBytes, { contentType: 'image/jpeg' }));
  await assertFails(uploadBytes(ref(storage, 'exports/bookings.csv'), imageBytes, { contentType: 'image/jpeg' }));
  await assertFails(getBytes(ref(storage, 'users/admin-avatar.jpg')));
});

test('Storage: an account with a missing role is not an admin', async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'users', 'roleless'), {
      name: 'Roleless',
      email: 'roleless@yatra.test',
    });
  });

  // No `role` field at all must never grant Storage write access.
  await assertFails(
    uploadBytes(
      ref(asUserStorage('roleless'), 'places/mustang-muktinath/roleless.jpg'),
      imageBytes,
      { contentType: 'image/jpeg' },
    ),
  );
});
