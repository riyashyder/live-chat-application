import 'dart:io';
import '../entities/message_entity.dart';
import '../entities/chat_entity.dart';

abstract class ChatRepository {
  
  Stream<List<ChatEntity>> getChats();

  
  Stream<List<MessageEntity>> getMessages(String chatId, {int limit = 50});

  
  Future<void> sendMessage({
    required String chatId,
    required String receiverId,
    required String text,
    String? messageId,
  });

  
  Future<void> sendImageMessage({
    required String chatId,
    required String receiverId,
    required File imageFile,
    String? messageId,
  });

  
  Future<void> sendAudioMessage({
    required String chatId,
    required String receiverId,
    required File audioFile,
    required int durationInSeconds,
    String? messageId,
  });

  
  Future<String> getOrCreateChat(String otherUserId);

  
  Future<void> updateTypingStatus({
    required String chatId,
    required bool isTyping,
  });

  
  Future<void> markMessagesAsRead(String chatId);

  
  Future<void> markMessagesAsDelivered(String chatId);

  
  Future<void> deleteMessage(String chatId, String messageId, {required bool forEveryone});

  
  Future<void> clearChat(String chatId);

  
  Stream<bool> getTypingStatus(String chatId, String otherUserId);

  
  Stream<MessageEntity?> getLastMessage(String chatId);
}
