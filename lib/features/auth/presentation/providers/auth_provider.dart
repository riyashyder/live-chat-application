import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:chat_app/core/providers/firebase_providers.dart';
import 'package:chat_app/core/providers/cloudinary_provider.dart';
import 'package:chat_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chat_app/features/auth/domain/entities/user_entity.dart';
import 'package:chat_app/features/auth/domain/repositories/auth_repository.dart';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
    cloudinary: ref.watch(cloudinaryProvider),
  );
});

// Current user ID
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).value?.uid;
});

// Auth state stream
final authStateProvider = StreamProvider.autoDispose<UserEntity?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// Current user data
final currentUserProvider = FutureProvider.autoDispose<UserEntity?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return null;
  return ref.watch(authRepositoryProvider).getUserById(uid);
});

// Get user by ID
final userByIdProvider = StreamProvider.family<UserEntity?, String>((ref, uid) {
  return ref.watch(authRepositoryProvider).getUserStreamById(uid);
});

// Search users
final searchUsersProvider = FutureProvider.family<List<UserEntity>, String>((ref, query) {
  if (query.isEmpty) return Future.value([]);
  return ref.watch(authRepositoryProvider).searchUsers(query);
});

// Auth notifier for actions (login, signup, logout)
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider), ref);
});

// Theme mode provider
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

@immutable
class AuthState {
  final bool isLoading;
  final String? error;
  final UserEntity? user;

  const AuthState({this.isLoading = false, this.error, this.user});

  AuthState copyWith({bool? isLoading, String? error, UserEntity? user}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final Ref _ref;

  AuthNotifier(this._repository, this._ref) : super(const AuthState());

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.signIn(
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
      return false;
    }
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    File? profileImage,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repository.signUp(
        name: name,
        email: email,
        password: password,
        profileImage: profileImage,
      );
      state = state.copyWith(isLoading: false, user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _getErrorMessage(e));
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
     
      await _repository.signOut();
      
      
      await _repository.clearAllData();
      
      
      await DefaultCacheManager().emptyCache();

      
      _ref.invalidate(currentUserProvider);
      _ref.invalidate(authStateProvider);
      
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Sign out failed. Please try again.');
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  String _getErrorMessage(dynamic e) {
    if (e is Exception) {
      final msg = e.toString();
      if (msg.contains('user-not-found')) return 'No user found with this email.';
      if (msg.contains('wrong-password')) return 'Incorrect password.';
      if (msg.contains('email-already-in-use')) return 'Email is already registered.';
      if (msg.contains('weak-password')) return 'Password is too weak.';
      if (msg.contains('invalid-email')) return 'Invalid email address.';
      if (msg.contains('invalid-credential')) return 'Invalid credentials. Please check your email and password.';
    }
    return 'An unexpected error occurred. Please try again.';
  }
}
