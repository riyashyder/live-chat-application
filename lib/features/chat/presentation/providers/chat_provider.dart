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
import 'package:uuid/uuid.dart';

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
    ref,
  );
});

final lastMessageStreamProvider = StreamProvider.family<MessageEntity?, String>((ref, chatId) {
  return ref.watch(chatRepositoryProvider).getLastMessage(chatId);
});

class ChatActionState {
  final bool isSending;
  final bool isRecording;
  final String? error;
  final Map<String, List<MessageEntity>> pendingMessages; // chatId -> list of messages

  const ChatActionState({
    this.isSending = false,
    this.isRecording = false,
    this.error,
    this.pendingMessages = const {},
  });

  ChatActionState copyWith({
    bool? isSending,
    bool? isRecording,
    String? error,
    Map<String, List<MessageEntity>>? pendingMessages,
  }) {
    return ChatActionState(
      isSending: isSending ?? this.isSending,
      isRecording: isRecording ?? this.isRecording,
      error: error,
      pendingMessages: pendingMessages ?? this.pendingMessages,
    );
  }
}

class ChatActionsNotifier extends StateNotifier<ChatActionState> {
  final ChatRepository _repository;
  final Ref _ref;
  final _uuid = const Uuid();
  Timer? _typingTimer;

  ChatActionsNotifier(this._repository, this._ref)
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
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    final tempMessage = MessageEntity(
      id: 'temp_${_uuid.v4()}',
      senderId: currentUserId,
      receiverId: receiverId,
      type: MessageType.image,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      localFilePath: imageFile.path,
    );

    // Add to pending
    final currentPending = Map<String, List<MessageEntity>>.from(state.pendingMessages);
    final chatPending = List<MessageEntity>.from(currentPending[chatId] ?? []);
    chatPending.add(tempMessage);
    currentPending[chatId] = chatPending;
    
    state = state.copyWith(pendingMessages: currentPending);

    try {
      await _repository.sendImageMessage(
        chatId: chatId,
        receiverId: receiverId,
        imageFile: imageFile,
        messageId: tempMessage.id,
      );
      
      // Wait a bit to ensure Firestore syncs before removing from pending
      await Future.delayed(const Duration(seconds: 2));
      
      // Remove from pending
      final updatedPending = Map<String, List<MessageEntity>>.from(state.pendingMessages);
      final updatedChatPending = List<MessageEntity>.from(updatedPending[chatId] ?? []);
      updatedChatPending.removeWhere((m) => m.id == tempMessage.id);
      updatedPending[chatId] = updatedChatPending;
      state = state.copyWith(pendingMessages: updatedPending);
    } catch (e) {
      // Remove from pending on error
      final updatedPending = Map<String, List<MessageEntity>>.from(state.pendingMessages);
      final updatedChatPending = List<MessageEntity>.from(updatedPending[chatId] ?? []);
      updatedChatPending.removeWhere((m) => m.id == tempMessage.id);
      updatedPending[chatId] = updatedChatPending;
      state = state.copyWith(pendingMessages: updatedPending, error: e.toString());
    }
  }

  Future<void> sendAudioMessage({
    required String chatId,
    required String receiverId,
    required File audioFile,
    required int durationInSeconds,
  }) async {
    final currentUserId = _ref.read(currentUserIdProvider);
    if (currentUserId == null) return;

    final tempMessage = MessageEntity(
      id: 'temp_${_uuid.v4()}',
      senderId: currentUserId,
      receiverId: receiverId,
      type: MessageType.audio,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      audioDuration: durationInSeconds,
      // localFilePath could be added for audio too if needed, but the user specifically asked for images
    );

    // Add to pending
    final currentPending = Map<String, List<MessageEntity>>.from(state.pendingMessages);
    final chatPending = List<MessageEntity>.from(currentPending[chatId] ?? []);
    chatPending.add(tempMessage);
    currentPending[chatId] = chatPending;
    
    state = state.copyWith(pendingMessages: currentPending);

    try {
      await _repository.sendAudioMessage(
        chatId: chatId,
        receiverId: receiverId,
        audioFile: audioFile,
        durationInSeconds: durationInSeconds,
        messageId: tempMessage.id,
      );
      
      // Safety delay
      await Future.delayed(const Duration(seconds: 2));

      final updatedPending = Map<String, List<MessageEntity>>.from(state.pendingMessages);
      final updatedChatPending = List<MessageEntity>.from(updatedPending[chatId] ?? []);
      updatedChatPending.removeWhere((m) => m.id == tempMessage.id);
      updatedPending[chatId] = updatedChatPending;
      state = state.copyWith(pendingMessages: updatedPending);
    } catch (e) {
      final updatedPending = Map<String, List<MessageEntity>>.from(state.pendingMessages);
      final updatedChatPending = List<MessageEntity>.from(updatedPending[chatId] ?? []);
      updatedChatPending.removeWhere((m) => m.id == tempMessage.id);
      updatedPending[chatId] = updatedChatPending;
      state = state.copyWith(pendingMessages: updatedPending, error: e.toString());
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
