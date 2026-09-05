import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  FirestoreService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<void> createOrUpdateUserProfile({
    required String name,
    String? phone,
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

    final existing = await userRef.get();

    if (!existing.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await userRef.set(
      data,
      SetOptions(merge: true),
    );
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final snapshot = await _users.doc(user.uid).get();

    if (!snapshot.exists) {
      return null;
    }

    return snapshot.data();
  }

  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('No authenticated user found.');
    }

    await _users.doc(user.uid).set(
      {
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
