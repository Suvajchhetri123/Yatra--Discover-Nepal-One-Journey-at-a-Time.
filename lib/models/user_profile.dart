import 'package:cloud_firestore/cloud_firestore.dart';

/// The single application role string that grants admin access.
///
/// Promotions are performed manually from the Firebase Console
/// (users/{uid}.role = 'admin'); there is no in-app way to obtain it.
const String kAdminRole = 'admin';

/// The role assigned to every newly created profile.
const String kTouristRole = 'tourist';

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final String? touristType;
  final String language;
  final String role;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.phone,
    this.touristType,
    this.language = 'English',
    this.role = kTouristRole,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.createdAt,
    this.updatedAt,
  });

  /// Returns a copy with the given fields replaced.
  ///
  /// Used when a write has already been persisted and the local snapshot needs
  /// to reflect it without re-reading Firestore. Omitted arguments keep their
  /// current value.
  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? touristType,
    String? language,
    String? role,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) {
    return UserProfile(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      touristType: touristType ?? this.touristType,
      language: language ?? this.language,
      role: role ?? this.role,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// Exact role check used for admin entry points and admin screens.
  ///
  /// Only the literal application role [kAdminRole] counts. Roles are never
  /// matched loosely and are never inferred from email, name, tourist type or
  /// a hard-coded account.
  bool get isAdmin => role == kAdminRole;

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String?,
      touristType: data['touristType'] as String?,
      language: data['language'] as String? ?? 'English',
      role: data['role'] as String? ?? kTouristRole,
      emergencyContactName: data['emergencyContactName'] as String?,
      emergencyContactPhone: data['emergencyContactPhone'] as String?,
      createdAt: _dateFromTimestamp(data['createdAt']),
      updatedAt: _dateFromTimestamp(data['updatedAt']),
    );
  }

  static DateTime? _dateFromTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }
}
