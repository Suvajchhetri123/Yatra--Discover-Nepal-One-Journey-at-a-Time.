import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

/// A user as the admin area needs to see it.
///
/// Passwords are never part of this model, are never read from Firestore and are
/// never displayed. Authentication credentials only exist inside Firebase
/// Authentication, which the client cannot read.
class AdminUserSummary {
  const AdminUserSummary({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone = '',
    this.touristType,
    this.disabled = false,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String? touristType;

  /// True when the trusted backend has disabled the Authentication account.
  final bool disabled;

  final DateTime? createdAt;

  bool get isAdmin => role == kAdminRole;

  String get displayName => name.isEmpty ? email : name;

  /// Builds a summary from an already-resolved profile.
  ///
  /// Used by the admin root, which has just verified the role from Firestore
  /// and must not read the profile twice.
  factory AdminUserSummary.fromProfile(UserProfile profile) {
    return AdminUserSummary(
      uid: profile.uid,
      name: profile.name,
      email: profile.email,
      phone: profile.phone ?? '',
      role: profile.role,
      touristType: profile.touristType,
      createdAt: profile.createdAt,
    );
  }

  factory AdminUserSummary.fromFirestore(
    String uid,
    Map<String, dynamic> data,
  ) {
    return AdminUserSummary(
      uid: uid,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      // Default to the tourist role so a profile that predates the role field
      // can never be mistaken for an admin.
      role: data['role'] as String? ?? kTouristRole,
      touristType: data['touristType'] as String?,
      disabled: data['accountDisabled'] as bool? ?? false,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}

/// Reads the `users` collection for the admin user-management area.
///
/// The visible list is plain Firestore: `users/{uid}` already holds everything
/// an administrator needs to see (name, email, phone, role, disabled flag) and
/// the existing Security Rules already allow an admin to read it. No client
/// ever lists Firebase Authentication accounts, which is not possible from a
/// client anyway.
///
/// Anything privileged (role change, disable, delete, password reset) goes
/// through [AdminUserActions], which calls the trusted backend.
abstract class AdminUserRepository {
  /// All registered users, most recently created first.
  Future<List<AdminUserSummary>> getUsers();

  /// A single user, or null when the profile no longer exists.
  Future<AdminUserSummary?> getUser(String uid);
}

class FirestoreAdminUserRepository implements AdminUserRepository {
  FirestoreAdminUserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<AdminUserSummary>> getUsers() async {
    final snapshot = await _firestore.collection('users').get();

    final users = snapshot.docs
        .map((doc) => AdminUserSummary.fromFirestore(doc.id, doc.data()))
        .toList();

    users.sort((a, b) {
      final byName = a.displayName.toLowerCase().compareTo(
        b.displayName.toLowerCase(),
      );

      if (byName != 0) return byName;

      return a.email.toLowerCase().compareTo(b.email.toLowerCase());
    });

    return users;
  }

  @override
  Future<AdminUserSummary?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();

    final data = doc.data();

    if (!doc.exists || data == null) return null;

    return AdminUserSummary.fromFirestore(doc.id, data);
  }
}
