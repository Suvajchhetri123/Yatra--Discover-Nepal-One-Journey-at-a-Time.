import 'package:cloud_firestore/cloud_firestore.dart';

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
    this.role = 'tourist',
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String?,
      touristType: data['touristType'] as String?,
      language: data['language'] as String? ?? 'English',
      role: data['role'] as String? ?? 'tourist',
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
