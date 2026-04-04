import 'dart:io';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Stream<UserEntity?> get authStateChanges;
  Future<UserEntity?> get currentUser;
  String? get currentUserId;
  Future<UserEntity> signIn({required String email, required String password});
  Future<UserEntity> signUp({
    required String name,
    required String email,
    required String password,
    File? profileImage,
  });
  Future<void> signOut();
  Future<void> updatePresence({required bool isOnline});
  Future<UserEntity?> getUserById(String uid);
  Stream<UserEntity?> getUserStreamById(String uid);
  Future<List<UserEntity>> searchUsers(String query);
  Future<void> updateProfile({
    String? name,
    String? statusText,
    File? profileImage,
  });

  /// Clears all local data, persistence, and caches
  Future<void> clearAllData();
}
