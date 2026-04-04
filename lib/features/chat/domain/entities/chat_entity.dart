import 'package:cloud_firestore/cloud_firestore.dart';

class ChatEntity {
  final String chatId;
  final List<String> participants;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String lastMessageSenderId;
  final String lastMessageType;
  final Map<String, int> unreadCounts;
  final Map<String, bool> typingStatus;

  const ChatEntity({
    required this.chatId,
    required this.participants,
    this.lastMessage = '',
    this.lastMessageTime,
    this.lastMessageSenderId = '',
    this.lastMessageType = 'text',
    this.unreadCounts = const {},
    this.typingStatus = const {},
    this.clearedAt = const {},
  });
 
  final Map<String, DateTime> clearedAt;

  int getUnreadCount(String uid) => unreadCounts['unreadCount_$uid'] ?? 0;
  bool isTyping(String uid) => typingStatus['typing_$uid'] ?? false;

  String getOtherParticipantId(String currentUid) {
    return participants.firstWhere(
      (id) => id != currentUid,
      orElse: () => '',
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'chatId': chatId,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : FieldValue.serverTimestamp(),
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageType': lastMessageType,
    };
    unreadCounts.forEach((key, value) => map[key] = value);
    typingStatus.forEach((key, value) => map[key] = value);
    return map;
  }

  factory ChatEntity.fromMap(Map<String, dynamic> map) {
    // Extract unread counts
    final unreadCounts = <String, int>{};
    final typingStatus = <String, bool>{};
    final clearedAt = <String, DateTime>{};
    map.forEach((key, value) {
      if (key.startsWith('unreadCount_') && value is int) {
        unreadCounts[key] = value;
      }
      if (key.startsWith('typing_') && value is bool) {
        typingStatus[key] = value;
      }
      if (key.startsWith('clearedAt_') && value is Timestamp) {
        clearedAt[key] = value.toDate();
      }
    });

    return ChatEntity(
      chatId: map['chatId'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] != null
          ? (map['lastMessageTime'] as Timestamp).toDate()
          : null,
      lastMessageSenderId: map['lastMessageSenderId'] ?? '',
      lastMessageType: map['lastMessageType'] ?? 'text',
      unreadCounts: unreadCounts,
      typingStatus: typingStatus,
      clearedAt: clearedAt,
    );
  }
}
