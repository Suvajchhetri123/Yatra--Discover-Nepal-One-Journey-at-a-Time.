import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<void> createOrUpdateUserProfile({
    required String name,
    String? phone,
    String? touristType,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('No authenticated user found.');
    }

    final userRef = _users.doc(user.uid);

    final data = <String, dynamic>{
      'name': name.trim(),
      'email': user.email,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (phone != null && phone.trim().isNotEmpty) {
      data['phone'] = phone.trim();
    }

    if (touristType != null && touristType.trim().isNotEmpty) {
      data['touristType'] = touristType.trim();
    }

    final existing = await userRef.get();

    if (!existing.exists) {
      data.addAll({
        'language': 'English',
        'role': 'tourist',
        'emergencyContactName': null,
        'emergencyContactPhone': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await userRef.set(data, SetOptions(merge: true));
  }

  Future<UserProfile?> getCurrentUserProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final snapshot = await _users.doc(user.uid).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();

    if (data == null) {
      return null;
    }

    return UserProfile.fromFirestore(snapshot.id, data);
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('No authenticated user found.');
    }

    await _users.doc(user.uid).set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updatePersonalInfo({required String name, String? phone}) async {
    final cleanName = name.trim();
    final cleanPhone = phone?.trim();

    await updateUserProfile({'name': cleanName, 'phone': cleanPhone});

    final user = _auth.currentUser;

    if (user != null && cleanName.isNotEmpty) {
      await user.updateDisplayName(cleanName);
    }
  }

  Future<void> updateEmergencyContact({
    required String name,
    required String phone,
  }) async {
    await updateUserProfile({
      'emergencyContactName': name.trim(),
      'emergencyContactPhone': phone.trim(),
    });
  }

  Future<void> updateLanguage(String language) async {
    await updateUserProfile({'language': language});
  }
}
