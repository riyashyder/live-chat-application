import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chat_app/core/services/cloudinary_service.dart';
import 'package:chat_app/core/constants/firestore_constants.dart';
import 'package:chat_app/features/auth/domain/entities/user_entity.dart';
import 'package:chat_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final CloudinaryService _cloudinary;

  AuthRepositoryImpl({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required CloudinaryService cloudinary,
  })  : _auth = auth,
        _firestore = firestore,
        _cloudinary = cloudinary;

  CollectionReference get _usersRef =>
      _firestore.collection(FirestoreConstants.usersCollection);

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Stream<UserEntity?> get authStateChanges {
    return _auth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return getUserById(user.uid);
    });
  }

  @override
  Future<UserEntity?> get currentUser async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return getUserById(user.uid);
  }

  @override
  Future<UserEntity> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _usersRef.doc(credential.user!.uid).update({
        FirestoreConstants.isOnline: true,
        FirestoreConstants.lastSeen: FieldValue.serverTimestamp(),
      });
      final user = await getUserById(credential.user!.uid);
      return user!;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  @override
  Future<UserEntity> signUp({
    required String name,
    required String email,
    required String password,
    File? profileImage,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String profileImageUrl = '';
      if (profileImage != null) {
        profileImageUrl = await _uploadProfileImage(
          credential.user!.uid,
          profileImage,
        );
      }

      final userEntity = UserEntity(
        uid: credential.user!.uid,
        name: name,
        email: email,
        profileImageUrl: profileImageUrl,
        isOnline: true,
        lastSeen: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await _usersRef.doc(credential.user!.uid).set(userEntity.toMap());
      return userEntity;
    } on FirebaseAuthException {
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await updatePresence(isOnline: false);
    await _auth.signOut();
  }

  @override
  Future<void> updatePresence({required bool isOnline}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _usersRef.doc(uid).update({
      FirestoreConstants.isOnline: isOnline,
      FirestoreConstants.lastSeen: FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<UserEntity?> getUserById(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists) return null;
    return UserEntity.fromMap(doc.data() as Map<String, dynamic>);
  }

  @override
  Stream<UserEntity?> getUserStreamById(String uid) {
    return _usersRef.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserEntity.fromMap(doc.data() as Map<String, dynamic>);
    });
  }

  @override
  Future<List<UserEntity>> searchUsers(String query) async {
    final currentUid = _auth.currentUser?.uid;
    final snapshot = await _usersRef
        .where(FirestoreConstants.name, isGreaterThanOrEqualTo: query)
        .where(FirestoreConstants.name, isLessThanOrEqualTo: '$query\uf8ff')
        .limit(20)
        .get();

    return snapshot.docs
        .map((doc) => UserEntity.fromMap(doc.data() as Map<String, dynamic>))
        .where((user) => user.uid != currentUid)
        .toList();
  }

  @override
  Future<void> updateProfile({
    String? name,
    String? statusText,
    File? profileImage,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final updates = <String, dynamic>{};
    if (name != null) updates[FirestoreConstants.name] = name;
    if (statusText != null) updates[FirestoreConstants.statusText] = statusText;

    if (profileImage != null) {
      final url = await _uploadProfileImage(uid, profileImage);
      updates[FirestoreConstants.profileImageUrl] = url;
    }

    if (updates.isNotEmpty) {
      await _usersRef.doc(uid).update(updates);
    }
  }

  @override
  Future<void> clearAllData() async {
    try {
      // Clear Firestore offline persistence
      await _firestore.clearPersistence();
    } catch (e) {
      // Ignore errors if persistence is already cleared or busy
    }
  }

  Future<String> _uploadProfileImage(String uid, File image) async {
    try {
      final url = await _cloudinary.uploadImage(
        image,
        'profile_images',
      );
      if (url == null) throw Exception('Upload failed');
      return url;
    } catch (e) {
      throw Exception('Failed to upload image to Cloudinary: $e');
    }
  }
}
