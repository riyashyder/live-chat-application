import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chat_app/core/providers/firebase_providers.dart';
import 'package:chat_app/core/providers/cloudinary_provider.dart';
import 'package:chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:chat_app/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/domain/entities/chat_entity.dart';
import 'package:chat_app/features/chat/domain/repositories/chat_repository.dart';

// Chat Repository Provider
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
    cloudinary: ref.watch(cloudinaryProvider),
  );
});

// All chats stream
final chatsStreamProvider = StreamProvider.autoDispose<List<ChatEntity>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);
  return ref.watch(chatRepositoryProvider).getChats();
});

// Messages stream for a specific chat
final messagesStreamProvider =
    StreamProvider.autoDispose.family<List<MessageEntity>, String>((ref, chatId) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);
  return ref.watch(chatRepositoryProvider).getMessages(chatId);
});

// Typing status for a specific chat
final typingStatusProvider =
    StreamProvider.family<bool, ({String chatId, String otherUserId})>(
        (ref, params) {
  return ref
      .watch(chatRepositoryProvider)
      .getTypingStatus(params.chatId, params.otherUserId);
});

// Chat actions notifier
final chatActionsProvider =
    StateNotifierProvider<ChatActionsNotifier, ChatActionState>((ref) {
  return ChatActionsNotifier(
    ref.watch(chatRepositoryProvider),
  );
});

final lastMessageStreamProvider = StreamProvider.family<MessageEntity?, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).getLastMessage(chatId);
});

class ChatActionState {
  final bool isSending;
  final bool isRecording;
  final String? error;

  const ChatActionState({
    this.isSending = false,
    this.isRecording = false,
    this.error,
  });

  ChatActionState copyWith({bool? isSending, bool? isRecording, String? error}) {
    return ChatActionState(
      isSending: isSending ?? this.isSending,
      isRecording: isRecording ?? this.isRecording,
      error: error,
    );
  }
}

class ChatActionsNotifier extends StateNotifier<ChatActionState> {
  final ChatRepository _repository;
  Timer? _typingTimer;

  ChatActionsNotifier(this._repository)
      : super(const ChatActionState());

  Future<String> getOrCreateChat(String otherUserId) async {
    return _repository.getOrCreateChat(otherUserId);
  }

  Future<void> sendTextMessage({
    required String chatId,
    required String receiverId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return;
    state = state.copyWith(isSending: true);
    try {
      await _repository.sendMessage(
        chatId: chatId,
        receiverId: receiverId,
        text: text.trim(),
      );
      state = state.copyWith(isSending: false);
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
    }
  }

  Future<void> sendImageMessage({
    required String chatId,
    required String receiverId,
    required File imageFile,
  }) async {
    state = state.copyWith(isSending: true);
    try {
      await _repository.sendImageMessage(
        chatId: chatId,
        receiverId: receiverId,
        imageFile: imageFile,
      );
      state = state.copyWith(isSending: false);
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
    }
  }

  Future<void> sendAudioMessage({
    required String chatId,
    required String receiverId,
    required File audioFile,
    required int durationInSeconds,
  }) async {
    state = state.copyWith(isSending: true);
    try {
      await _repository.sendAudioMessage(
        chatId: chatId,
        receiverId: receiverId,
        audioFile: audioFile,
        durationInSeconds: durationInSeconds,
      );
      state = state.copyWith(isSending: false);
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
    }
  }

  void onTypingChanged(String chatId, String text) {
    _typingTimer?.cancel();
    if (text.isNotEmpty) {
      _repository.updateTypingStatus(chatId: chatId, isTyping: true);
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _repository.updateTypingStatus(chatId: chatId, isTyping: false);
      });
    } else {
      _repository.updateTypingStatus(chatId: chatId, isTyping: false);
    }
  }

  Future<void> markAsRead(String chatId) async {
    await _repository.markMessagesAsRead(chatId);
  }

  Future<void> markAsDelivered(String chatId) async {
    await _repository.markMessagesAsDelivered(chatId);
  }

  Future<void> deleteMessage(String chatId, String messageId, {required bool forEveryone}) async {
    await _repository.deleteMessage(chatId, messageId, forEveryone: forEveryone);
  }

  Future<void> clearChat(String chatId) async {
    await _repository.clearChat(chatId);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }
}
