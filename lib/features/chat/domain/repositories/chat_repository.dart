import 'dart:io';
import '../entities/message_entity.dart';
import '../entities/chat_entity.dart';

abstract class ChatRepository {
  /// Get all chats for the current user as a stream
  Stream<List<ChatEntity>> getChats();

  /// Get messages for a specific chat as a stream (with pagination support)
  Stream<List<MessageEntity>> getMessages(String chatId, {int limit = 50});

  /// Send a text message
  Future<void> sendMessage({
    required String chatId,
    required String receiverId,
    required String text,
    String? messageId,
  });

  /// Send an image message
  Future<void> sendImageMessage({
    required String chatId,
    required String receiverId,
    required File imageFile,
    String? messageId,
  });

  /// Send an audio message
  Future<void> sendAudioMessage({
    required String chatId,
    required String receiverId,
    required File audioFile,
    required int durationInSeconds,
    String? messageId,
  });

  /// Create or get existing chat between two users
  Future<String> getOrCreateChat(String otherUserId);

  /// Update typing status
  Future<void> updateTypingStatus({
    required String chatId,
    required bool isTyping,
  });

  /// Mark messages as read
  Future<void> markMessagesAsRead(String chatId);

  /// Mark messages as delivered
  Future<void> markMessagesAsDelivered(String chatId);

  /// Delete a message (either for me or for everyone)
  Future<void> deleteMessage(String chatId, String messageId, {required bool forEveryone});

  /// Clear all messages in a chat for the current user
  Future<void> clearChat(String chatId);

  /// Stream typing status for a chat
  Stream<bool> getTypingStatus(String chatId, String otherUserId);

  /// Get the last visible message for the current user
  Stream<MessageEntity?> getLastMessage(String chatId);
}
