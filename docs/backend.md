# Yatra Backend Documentation

## Project

**Yatra – Discover Nepal, One Journey at a Time**

Academic project title:

**Nepal Travel Planning and Recommendation Application**

Yatra is a Flutter application for tourists travelling in Nepal. Firebase is used for authentication, persistent data, image storage, and privileged administrative operations.

---

## 1. Backend Technologies

The backend uses the following Firebase services:

- **Firebase Authentication** – user login and account identity
- **Cloud Firestore** – application database
- **Firebase Storage** – place image storage
- **Cloud Functions** – privileged administrative user operations

The Flutter application communicates directly with Firestore for operations allowed by security rules.

Administrative operations that require Firebase Authentication privileges are performed through Cloud Functions.

Normal admin work is performed from the Yatra Admin interface. Firebase Console is intended only for infrastructure, deployment, debugging, and initial project configuration.

---

## 2. Authentication

Yatra currently uses Firebase email and password authentication.

After login, the application reads the user's Firestore profile and determines the user's role.

Supported application roles are:

- `tourist`
- `admin`

New users are created as tourists.

Users cannot select or modify their own role from the client application.

---

## 3. Role-Based Routing

After authentication, Yatra uses the user's profile role to determine the correct interface.

### Tourist

A tourist is directed to the normal Yatra tourist interface.

The tourist can:

- browse active destinations and packages
- plan a trip
- generate recommendations
- create bookings
- view their own bookings
- cancel eligible pending bookings
- manage their own profile
- use SOS and offline-related features

### Admin

An admin is directed to the dedicated Admin interface.

The admin can manage:

- bookings
- coordinators
- places
- packages
- users
- application content

Admins do not normally enter the tourist Home screen.

A separate **Preview as Tourist** feature allows an administrator to preview the tourist interface without changing their admin role.

---

## 4. Shared Application State

Yatra keeps frequently used Firestore information in application-level controllers.

### ProfileSession

`ProfileSession` stores the currently loaded Firestore user profile.

This avoids unnecessary repeated reads of the same `users/{uid}` document while moving between screens.

Firestore remains the source of truth.

The profile session is refreshed when required and updated after successful profile changes.

### TouristCatalogController

`TouristCatalogController` manages the tourist-facing place and package catalog.

The controller is provided above `MaterialApp`, which means routes created by the application Navigator can access the same catalog.

The catalog is loaded when the tourist Home or tourist preview requires it.

This prevents every planner screen from independently querying Firestore.

The same loaded place catalog is therefore available to screens such as:

- Home
- Package Details
- trip-planning screens
- Boarding
- Recommendation

This is important because recommendation generation and trip cost estimation must use the same administrator-managed place data.

---

## 5. Firestore Collections

### `users`

Stores application user profiles.

Important fields include:

- `uid`
- `name`
- `email`
- `phone`
- `touristType`
- `language`
- `role`
- `emergencyContactName`
- `emergencyContactPhone`
- `accountDisabled`
- `accountDeleted`
- timestamps

A tourist can read and update permitted fields of their own profile.

Sensitive account and role fields cannot be changed directly by a tourist.

Admins can access user information required for administration.

### `bookings`

Stores persisted itinerary bookings.

A booking contains information such as:

- user ID
- booking code
- booking status
- creation/update timestamps
- tourist information
- trip dates
- travel type
- budget
- selected destination
- route information
- outbound route
- return route
- stop plans
- generated day plans
- coordinator snapshot
- place and pricing snapshots

Bookings are stored in Firestore and therefore remain available after application restart.

Tourists can access their own bookings.

Administrators can access bookings for administration and coordinator assignment.

### `coordinators`

Stores coordinator records managed by administrators.

Coordinator data used by a confirmed booking is copied into the booking as a historical snapshot.

### `places`

Stores administrator-managed destinations and attractions.

Tourists receive active place records.

Administrators can create and update place records.

### `packages`

Stores administrator-managed travel packages.

Tourists receive active package records.

Administrators can create, update, activate, and deactivate packages.

### `system`

Protected system documents can be used for backend coordination and administrative guards.

Normal tourist clients cannot modify protected system/admin guard documents.

---

## 6. Booking Snapshots

Historical booking information is stored as snapshots.

When important information is used in a booking, relevant values are copied into the booking document.

This can include:

- place information
- tourist pricing
- route information
- coordinator information
- itinerary information

Later administrative edits therefore do not silently change an old booking.

For example, if an administrator changes a coordinator's phone number after a booking is confirmed, the historical coordinator details stored with the existing booking remain unchanged.

This protects booking history and makes existing records reproducible.

---

## 7. Booking Status and Administration

Tourists can create bookings according to the application's booking rules.

A tourist can cancel an eligible pending booking.

Administrative booking operations are separated from tourist booking operations.

An administrator can:

- review bookings
- inspect booking details
- assign coordinators
- update permitted booking status information

Coordinator information is stored as a booking snapshot when assigned.

The runtime application no longer depends on a demo booking store.

---

## 8. Places

The `places` collection stores administrator-managed places and attractions.

Place information can include:

- name
- region or destination information
- description
- tourist pricing
- image information
- active status
- travel-related metadata

Tourists receive active place records.

Administrators can create and edit place records.

Instead of permanently deleting normal catalog records, Yatra uses an `active` state.

For example:

```text
active = true
```

means the item can be shown to tourists.

```text
active = false
```

means the item is hidden from normal tourist use.

This is a **soft-delete/deactivation model**.

---

## 9. Packages

The `packages` collection stores administrator-managed travel packages.

A package can contain information such as:

- title
- summary
- region
- duration
- difficulty
- price
- rating
- associated places
- image
- active status

Tourists receive active packages.

Administrators can create, update, activate, and deactivate packages.

The Home screen reads the Firestore-backed package catalog rather than using bundled package data as the production source.

---

## 10. Coordinators

The `coordinators` collection stores coordinator information.

Administrators can manage coordinator records.

Tourists do not directly manage coordinators.

When a coordinator is assigned to a booking, the information required by that booking is copied into the booking snapshot.

This prevents future coordinator edits from changing historical bookings.

---

## 11. Seed Data

The project still contains bundled seed fixtures for development and initial migration.

Seed sources include:

- `lib/data/places_data.dart`
- `lib/data/packages_data.dart`
- `lib/data/mock_coordinators.dart`

These files are not the normal production runtime database.

They are used by `CatalogSeedService` to populate Firestore when required.

The seed operation uses stable identifiers so running the migration again does not create duplicate copies of the same seed records.

After migration, administrators manage catalog data through the Admin interface.

---

## 12. Business Data vs Algorithm Constants

Administrator-managed business and content data is stored in Firestore.

Examples include:

- places
- packages
- coordinators
- user profiles
- bookings

Some values remain in application code because they are part of the planning algorithm rather than CMS content.

Examples include:

- transportation integration logic
- transport icons
- routing rules
- recommendation rules
- destination cost-profile configuration used by the planner

Keeping algorithm configuration in code is different from using hard-coded production catalog records.

---

## 13. Tourist Pricing

Yatra supports different tourist categories.

Pricing is resolved through the application's tourist-pricing model.

Internally, prices are represented using canonical Nepalese Rupees where required by the planning and estimation logic.

Displayed currency handling is kept separate from the underlying canonical pricing.

The same pricing model is used by the trip-cost estimator so that budget validation and recommendation generation remain consistent.

---

## 14. Budget Validation

Yatra contains budget validation for both package and custom-trip planning.

For custom routes, final budget validation uses the application's shared `TripCostEstimator`.

The calculation can use information such as:

- route
- places
- tourist type
- group size
- travel dates
- trip configuration

The estimator uses the current catalog information rather than an unrelated bundled place list.

This keeps the budget gate and recommendation data consistent.

---

## 15. Recommendation Data

`RecommendationService` receives place catalog data instead of directly importing bundled place seed data.

This keeps recommendation generation deterministic while allowing Firestore-administered attraction information to be used.

The recommendation service itself remains planning logic and does not perform Firestore reads.

This separates:

- database access
- application state
- recommendation algorithm

---

## 16. Place Images

Place images are stored using Firebase Storage.

The Admin interface supports multiple place photos.

The application limits the number of place images according to its configured maximum.

The first or reordered image can act as the cover image while maintaining compatibility with older single-image application boundaries.

Storage rules restrict uploads to expected place-image paths.

Uploads are restricted by authorization, file type, and configured maximum file size.

---

## 17. Firestore Security

Firestore Security Rules enforce backend authorization independently of the Flutter interface.

Important protections include:

- anonymous users cannot access protected application data
- tourists cannot promote themselves to admin
- tourists cannot modify protected account-status fields
- tourists cannot write catalog records
- tourists only access bookings permitted by ownership rules
- admin catalog writes require administrator authorization
- inactive catalog records are not exposed through normal tourist access
- protected system/admin guard records cannot be written by normal clients
- destructive catalog deletes are restricted in favor of soft deactivation

Therefore, hiding an Admin button in Flutter is not the security mechanism.

Firestore Security Rules provide the actual backend authorization boundary.

---

## 18. Firebase Storage Security

Firebase Storage has its own security rules.

The rules protect place-image storage separately from Firestore.

Important protections include:

- authentication requirements
- administrator upload authorization
- expected storage paths
- image content-type restrictions
- maximum upload size restrictions
- unrelated storage paths are denied

Firestore rules and Storage rules therefore protect different backend resources.

---

## 19. Privileged User Administration

Some account operations cannot safely be performed directly from a normal Flutter client.

Yatra uses Cloud Functions for privileged user administration.

Supported administrative actions include operations such as:

- promote user
- demote user
- disable account
- enable account
- delete account
- password-reset administration

Cloud Functions verify the caller's administrator privileges before privileged operations are performed.

No plaintext user passwords are stored by Yatra.

Password reset uses Firebase Authentication's password-reset mechanism.

---

## 20. Password Reset

Password reset is handled through Firebase Authentication.

The application uses Firebase's password-reset email flow rather than generating or storing user passwords.

Administrative backend code can identify the target user, while the actual password reset remains controlled by Firebase Authentication.

This avoids insecure password storage or custom password-reset links.

---

## 21. Last-Admin Protection

Yatra contains protection against accidentally removing the final administrator.

The backend uses a serialized Firestore guard and transaction mechanism before privileged role or account changes are applied.

Because Firebase Authentication and Firestore are separate services, they cannot participate in one true cross-service atomic transaction.

The implementation therefore uses transaction-based guarding together with compensation logic around Authentication mutations.

This should be described accurately as:

**Protected and compensated consistency, not a single atomic transaction across Firebase Authentication and Firestore.**

This also protects against simultaneous attempts to remove the last administrator.

---

## 22. Preview as Tourist

An administrator can use **Preview as Tourist** to inspect the tourist-facing application.

The administrator remains authenticated as an administrator.

The preview interface provides:

- a persistent Admin Preview indication
- an Exit action
- the real tourist-facing interface
- normal write protections

The administrator's identity or role is not changed merely to preview the tourist interface.

The preview uses the same tourist catalog architecture as the normal tourist application.

---

## 23. Soft Delete

Places, packages, and coordinators use deactivation instead of routine physical deletion.

Example:

```text
active: false
```

Benefits include:

- historical references remain valid
- existing bookings keep meaningful records
- accidental permanent data loss is reduced
- administrators can reactivate content later

Booking snapshots provide an additional historical boundary.

---

## 24. Profile Session

The application uses `ProfileSession` as a shared profile cache.

The production loader reads the current user profile from Firestore.

The session is provided above application navigation so multiple screens can access the same profile snapshot.

This reduces repeated profile reads while keeping Firestore as the source of truth.

The implementation is designed so widget tests that do not initialize Firebase can still construct the application safely.

---

## 25. Tourist Catalog Architecture

The application uses one shared `TouristCatalogController`.

In production, the controller is provided through `TouristCatalogScope` above `MaterialApp`.

This is important because Flutter routes pushed by a Navigator inherit widgets that are above the Navigator, but they do not automatically inherit a scope created only inside a previous route.

The resulting structure is approximately:

```text
YatraApp
  |
  +-- ProfileSessionScope
  |
  +-- TouristCatalogScope
        |
        +-- MaterialApp
              |
              +-- Navigator
                    |
                    +-- Home
                    +-- Plan Trip
                    +-- Travel Dates
                    +-- Travel Group
                    +-- Age
                    +-- Budget
                    +-- Destination
                    +-- Season Analysis
                    +-- Boarding
                    +-- Recommendation
```

This ensures planner routes can access the same Firestore-backed catalog.

Home triggers catalog loading when required.

The controller is not required to query Firestore merely because the application object exists.

For widget tests, `HomeScreen` can still receive an injected fake catalog and publish it locally for descendants.

---

## 26. Firebase Console Usage

Normal system operation should not require Firebase Console.

The administrator performs routine application management from the Yatra Admin interface.

Firebase Console or Firebase CLI may still be required for:

- initial Firebase setup
- deploying rules
- deploying Cloud Functions
- infrastructure configuration
- debugging
- emergency maintenance

This separation makes the Admin panel the normal application-level content management interface.

---

## 27. Testing

The project contains automated tests for:

- Flutter application behavior
- catalog migration
- catalog injection
- recommendation generation
- booking persistence
- itinerary editing
- Google Maps navigation
- administrator functionality
- Cloud Functions
- Firestore Security Rules
- Firebase Storage Rules
- last-admin protection
- role escalation prevention
- active/inactive catalog access

Current verified test baseline during backend integration:

```text
Flutter analyze: No issues found
Flutter tests: 444/444 passed
Catalog migration tests: 18/18 passed
Cloud Functions tests: 34/34 passed
Firestore + Storage rules tests: 21/21 passed
```

The itinerary editing test may produce a non-fatal Flutter hit-test warning for an off-screen test tap, but the test itself passes.

Automated testing does not replace real-device acceptance testing.

---

## 28. Firebase Configuration

The Firebase project configuration includes:

- Firestore
- Firebase Storage
- Cloud Functions
- Firebase Authentication

Firestore uses the project's configured database and region.

The application Firebase project is configured through FlutterFire-generated configuration.

Android is a primary deployment target.

---

## 29. Deployment

Before deployment, automated tests should pass.

Typical deployment commands are:

```bash
firebase deploy --only firestore:rules
```

```bash
firebase deploy --only storage
```

```bash
firebase deploy --only functions
```

Firestore indexes only need to be deployed when the index configuration has changed.

Cloud Functions deployment may require the appropriate Firebase billing plan.

Deployment should be performed only after final real-device acceptance testing.

---

## 30. Production Data Flow

A simplified tourist flow is:

```text
Firebase Authentication
        |
        v
Firestore User Profile
        |
        v
App Entry / Role Resolution
        |
        v
Tourist Home
        |
        +---- Firestore Packages
        |
        +---- Firestore Places
        |
        v
Shared TouristCatalogController
        |
        v
Trip Planner
        |
        v
Trip Cost Estimator
        |
        v
Recommendation Service
        |
        v
Booking
        |
        v
Cloud Firestore
```

A simplified administrator flow is:

```text
Firebase Authentication
        |
        v
Admin Role Verification
        |
        v
Admin Dashboard
        |
        +---- Manage Places
        |
        +---- Manage Packages
        |
        +---- Manage Coordinators
        |
        +---- Manage Bookings
        |
        +---- Manage Users
                    |
                    v
              Cloud Functions
              for privileged
              Auth operations
```

---

## 31. Security Model Summary

Yatra uses multiple layers of security.

### Client Interface

The Flutter application only exposes actions appropriate to the current role.

### Firestore Security Rules

Firestore rules independently verify whether database reads and writes are allowed.

### Firebase Storage Rules

Storage rules independently protect uploaded image files.

### Cloud Functions

Privileged Firebase Authentication operations are performed on the trusted backend.

This means security does not depend only on what buttons are visible in the Flutter application.

---

## 32. Data Persistence

Production bookings, profiles, catalog records, and coordinator records are persisted in Firebase.

The application no longer depends on temporary in-memory demo stores for production behavior.

Persisted booking records remain available after the application is restarted.

Catalog changes performed by administrators are stored in Firestore and become available to tourist users through the shared catalog controller.

---

## 33. Historical Integrity

Historical integrity is maintained primarily through booking snapshots.

When a booking is created or updated with relevant catalog or coordinator information, important values are copied into the booking.

Later CMS changes therefore affect future planning and browsing without rewriting historical booking details.

This separation is important because live catalog content and historical transaction data serve different purposes.

---

## 34. Separation of Responsibilities

The backend architecture separates responsibilities between components.

### Firestore Services and Repositories

Responsible for persistent database access.

### TouristCatalogController

Responsible for loading, caching, refreshing, and exposing tourist catalog information.

### ProfileSession

Responsible for holding the current profile snapshot.

### RecommendationService

Responsible for recommendation and itinerary-generation logic.

### TripCostEstimator

Responsible for trip cost calculations and budget validation.

### Cloud Functions

Responsible for privileged account administration.

### Security Rules

Responsible for enforcing backend authorization.

This separation makes the project easier to test and maintain.

---

## 35. Final Architecture Summary

Yatra uses Firebase as a secure persistent backend while keeping travel-planning logic inside the Flutter application.

The main architectural principles are:

- Firebase Authentication provides identity.
- Cloud Firestore is the persistent application database.
- Firebase Storage stores administrator-managed place images.
- Cloud Functions perform privileged Authentication operations.
- Firestore and Storage rules enforce backend authorization.
- production catalog data is administrator-managed.
- bundled place, package, and coordinator records are seed fixtures only.
- inactive records use soft deletion.
- bookings store historical snapshots.
- recommendation logic is separated from database access.
- trip-cost estimation uses the current catalog.
- tourist catalog state is shared above application navigation.
- profile state is shared through `ProfileSession`.
- administrators use the Yatra Admin interface for normal management.
- Firebase Console is reserved for infrastructure and debugging.
- automated tests protect the backend and application from regressions.
