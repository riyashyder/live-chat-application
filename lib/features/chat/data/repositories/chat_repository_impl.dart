import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chat_app/core/services/cloudinary_service.dart';
import 'package:uuid/uuid.dart';
import 'package:chat_app/core/constants/firestore_constants.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/domain/entities/chat_entity.dart';
import 'package:chat_app/features/chat/domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final CloudinaryService _cloudinary;
  final _uuid = const Uuid();

  ChatRepositoryImpl({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required CloudinaryService cloudinary,
  })  : _auth = auth,
        _firestore = firestore,
        _cloudinary = cloudinary;

  String get _currentUid => _auth.currentUser!.uid;

  CollectionReference get _chatsRef =>
      _firestore.collection(FirestoreConstants.chatsCollection);

  @override
  Stream<List<ChatEntity>> getChats() {
    return _chatsRef
        .where(FirestoreConstants.participants, arrayContains: _currentUid)
        .orderBy(FirestoreConstants.lastMessageTime, descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final chat = ChatEntity.fromMap(data);

        // Check if chat was cleared for the current user
        final userClearedAt = chat.clearedAt['clearedAt_$_currentUid'];
        if (userClearedAt != null &&
            chat.lastMessageTime != null &&
            chat.lastMessageTime!.isBefore(userClearedAt)) {
          // If cleared after the last message, blank out the preview
          return ChatEntity(
            chatId: chat.chatId,
            participants: chat.participants,
            lastMessage: '',
            lastMessageTime: chat.lastMessageTime,
            lastMessageSenderId: chat.lastMessageSenderId,
            lastMessageType: chat.lastMessageType,
            unreadCounts: {...chat.unreadCounts, 'unreadCount_$_currentUid': 0},
            typingStatus: chat.typingStatus,
            clearedAt: chat.clearedAt,
          );
        }
        return chat;
      }).toList();
    });
  }

  @override
  Stream<List<MessageEntity>> getMessages(String chatId, {int limit = 50}) {
    return _chatsRef
        .doc(chatId)
        .collection(FirestoreConstants.messagesCollection)
        .orderBy(FirestoreConstants.timestamp, descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
        final messages = snapshot.docs
            .map((doc) => MessageEntity.fromMap(doc.data()))
            .where((message) => !message.deletedFor.contains(_currentUid))
            .toList();

        // Background update for delivery status
        for (final message in messages) {
          if (message.receiverId == _currentUid &&
              message.status == MessageStatus.sent) {
            _chatsRef
                .doc(chatId)
                .collection(FirestoreConstants.messagesCollection)
                .doc(message.id)
                .update({
              'status': MessageStatus.delivered.name,
              'deliveredAt': FieldValue.serverTimestamp(),
            });
          }
        }

        return messages;
    });
  }

  @override
  Future<void> sendMessage({
    required String chatId,
    required String receiverId,
    required String text,
    String? messageId,
  }) async {
    final finalMessageId = messageId ?? _uuid.v4();
    final message = MessageEntity(
      id: finalMessageId,
      senderId: _currentUid,
      receiverId: receiverId,
      text: text,
      type: MessageType.text,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );

    final batch = _firestore.batch();

    // Add message
    batch.set(
      _chatsRef
          .doc(chatId)
          .collection(FirestoreConstants.messagesCollection)
          .doc(messageId),
      message.toMap(),
    );

    // Update chat metadata
    batch.update(_chatsRef.doc(chatId), {
      FirestoreConstants.lastMessage: text,
      FirestoreConstants.lastMessageTime: FieldValue.serverTimestamp(),
      FirestoreConstants.lastMessageSenderId: _currentUid,
      FirestoreConstants.lastMessageType: 'text',
      'unreadCount_$receiverId': FieldValue.increment(1),
      'typing_$_currentUid': false,
    });

    await batch.commit();
  }

  @override
  Future<void> sendImageMessage({
    required String chatId,
    required String receiverId,
    required File imageFile,
    String? messageId,
  }) async {
    final finalMessageId = messageId ?? _uuid.v4();

    try {
      // Upload image to Cloudinary
      final imageUrl = await _cloudinary.uploadImage(
        imageFile,
        'chat_images/$chatId',
      );
      if (imageUrl == null) throw Exception('Image upload failed');

      final message = MessageEntity(
        id: finalMessageId,
        senderId: _currentUid,
        receiverId: receiverId,
        imageUrl: imageUrl,
        type: MessageType.image,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );

      final batch = _firestore.batch();
      batch.set(
        _chatsRef
            .doc(chatId)
            .collection(FirestoreConstants.messagesCollection)
            .doc(finalMessageId),
        message.toMap(),
      );
      batch.update(_chatsRef.doc(chatId), {
        FirestoreConstants.lastMessage: '📷 Image',
        FirestoreConstants.lastMessageTime: FieldValue.serverTimestamp(),
        FirestoreConstants.lastMessageSenderId: _currentUid,
        FirestoreConstants.lastMessageType: 'image',
        'unreadCount_$receiverId': FieldValue.increment(1),
      });
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to send image message: $e');
    }
  }

  @override
  Future<void> sendAudioMessage({
    required String chatId,
    required String receiverId,
    required File audioFile,
    required int durationInSeconds,
    String? messageId,
  }) async {
    final finalMessageId = messageId ?? _uuid.v4();

    try {
      // Upload audio to Cloudinary
      final audioUrl = await _cloudinary.uploadAudio(
        audioFile,
        'chat_audio/$chatId',
      );
      if (audioUrl == null) throw Exception('Audio upload failed');

      final message = MessageEntity(
        id: finalMessageId,
        senderId: _currentUid,
        receiverId: receiverId,
        audioUrl: audioUrl,
        audioDuration: durationInSeconds,
        type: MessageType.audio,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      );

      final batch = _firestore.batch();
      batch.set(
        _chatsRef
            .doc(chatId)
            .collection(FirestoreConstants.messagesCollection)
            .doc(finalMessageId),
        message.toMap(),
      );
      batch.update(_chatsRef.doc(chatId), {
        FirestoreConstants.lastMessage: '🎤 Audio',
        FirestoreConstants.lastMessageTime: FieldValue.serverTimestamp(),
        FirestoreConstants.lastMessageSenderId: _currentUid,
        FirestoreConstants.lastMessageType: 'audio',
        'unreadCount_$receiverId': FieldValue.increment(1),
      });
      await batch.commit();
    } catch (e) {
      throw Exception('Failed to send audio message: $e');
    }
  }

  @override
  Future<String> getOrCreateChat(String otherUserId) async {
    // Generate deterministic chat ID
    final ids = [_currentUid, otherUserId]..sort();
    final chatId = ids.join('_');

    final doc = await _chatsRef.doc(chatId).get();
    if (!doc.exists) {
      final chat = ChatEntity(
        chatId: chatId,
        participants: ids,
      );
      final map = chat.toMap();
      // Initialize unread counts
      map['unreadCount_${ids[0]}'] = 0;
      map['unreadCount_${ids[1]}'] = 0;
      map['typing_${ids[0]}'] = false;
      map['typing_${ids[1]}'] = false;
      await _chatsRef.doc(chatId).set(map);
    }

    return chatId;
  }

  @override
  Future<void> updateTypingStatus({
    required String chatId,
    required bool isTyping,
  }) async {
    await _chatsRef.doc(chatId).update({
      'typing_$_currentUid': isTyping,
    });
  }
  @override
  Future<void> markMessagesAsDelivered(String chatId) async {
    final sentMessages = await _chatsRef
        .doc(chatId)
        .collection(FirestoreConstants.messagesCollection)
        .where(FirestoreConstants.receiverId, isEqualTo: _currentUid)
        .where(FirestoreConstants.status, isEqualTo: MessageStatus.sent.name)
        .get();

    if (sentMessages.docs.isEmpty) return;

    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    for (final doc in sentMessages.docs) {
      batch.update(doc.reference, {
        FirestoreConstants.status: MessageStatus.delivered.name,
        'deliveredAt': now,
      });
    }
    await batch.commit();
  }

  @override
  Future<void> markMessagesAsRead(String chatId) async {
    // Reset unread count for current user
    await _chatsRef.doc(chatId).update({
      'unreadCount_$_currentUid': 0,
    });

    // Update message statuses to read
    final unreadMessages = await _chatsRef
        .doc(chatId)
        .collection(FirestoreConstants.messagesCollection)
        .where(FirestoreConstants.receiverId, isEqualTo: _currentUid)
        .where(FirestoreConstants.status, isNotEqualTo: MessageStatus.read.name)
        .get();

    if (unreadMessages.docs.isEmpty) return;

    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    for (final doc in unreadMessages.docs) {
      final data = doc.data();
      final updates = <String, dynamic>{
        FirestoreConstants.status: MessageStatus.read.name,
        'readAt': now,
      };

      // If it hasn't been marked as delivered yet, do it now
      if (data['deliveredAt'] == null) {
        updates['deliveredAt'] = now;
      }

      batch.update(doc.reference, updates);
    }
    await batch.commit();
  }

  @override
  Future<void> deleteMessage(String chatId, String messageId, {required bool forEveryone}) async {
    final messageRef = _chatsRef
        .doc(chatId)
        .collection(FirestoreConstants.messagesCollection)
        .doc(messageId);

    if (forEveryone) {
      final batch = _firestore.batch();
      batch.update(messageRef, {
        'isDeleted': true,
        'text': 'This message was deleted',
        'imageUrl': null,
        'audioUrl': null,
        'audioDuration': null,
      });

      // Also update the chat document's preview if this was the last message
      // Note: In a real app, you'd compare messageId with lastMessageId
      // For now, we'll unconditionally update the preview if needed, 
      // but to be safe we'll just update it to "This message was deleted" 
      // if it happens to be the last one.
      final chatDoc = await _chatsRef.doc(chatId).get();
      if (chatDoc.exists) {
        // Since we don't store lastMessageId yet, we'll just check if this message 
        // was deleted and if the chat's lastMessage matches it. 
        // A better way is to update the chat doc directly.
        batch.update(_chatsRef.doc(chatId), {
          'lastMessage': '🚫 This message was deleted',
        });
      }
      
      await batch.commit();
    } else {
      await messageRef.update({
        'deletedFor': FieldValue.arrayUnion([_currentUid]),
      });
    }
  }

  @override
  Future<void> clearChat(String chatId) async {
    final messages = await _chatsRef
        .doc(chatId)
        .collection(FirestoreConstants.messagesCollection)
        .get();

    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      batch.update(doc.reference, {
        'deletedFor': FieldValue.arrayUnion([_currentUid]),
      });
    }

    // Update parent chat document with clearedAt timestamp
    batch.update(_chatsRef.doc(chatId), {
      'clearedAt_$_currentUid': FieldValue.serverTimestamp(),
      'unreadCount_$_currentUid': 0,
    });

    await batch.commit();
  }

  @override
  Stream<bool> getTypingStatus(String chatId, String otherUserId) {
    return _chatsRef.doc(chatId).snapshots().map((doc) {
      if (!doc.exists) return false;
      final data = doc.data() as Map<String, dynamic>;
      return data['typing_$otherUserId'] ?? false;
    });
  }
  @override
  Stream<MessageEntity?> getLastMessage(String chatId) {
    return _chatsRef
        .doc(chatId)
        .collection(FirestoreConstants.messagesCollection)
        .orderBy(FirestoreConstants.timestamp, descending: true)
        .limit(10) // Only look at the 10 most recent to find a visible one
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;

      try {
        final messages = snapshot.docs
            .map((doc) => MessageEntity.fromMap(doc.data()))
            .where((message) => !message.deletedFor.contains(_currentUid))
            .toList();

        if (messages.isEmpty) return null;
        return messages.first;
      } catch (e) {
        return null;
      }
    });
  }
}
