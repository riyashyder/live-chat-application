import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, audio }

enum MessageStatus { sent, delivered, read }

class MessageEntity {
  final String id;
  final String senderId;
  final String receiverId;
  final String? text;
  final String? imageUrl;
  final String? audioUrl;
  final int? audioDuration; 
  final MessageType type;
  final DateTime timestamp;
  final MessageStatus status;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final bool isDeleted;
  final List<String> deletedFor;
  final String? localFilePath; 

  const MessageEntity({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.text,
    this.imageUrl,
    this.audioUrl,
    this.audioDuration,
    required this.type,
    required this.timestamp,
    this.deliveredAt,
    this.readAt,
    this.status = MessageStatus.sent,
    this.isDeleted = false,
    this.deletedFor = const [],
    this.localFilePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'audioDuration': audioDuration,
      'type': type.name,
      'timestamp': FieldValue.serverTimestamp(),
      'deliveredAt': deliveredAt != null ? Timestamp.fromDate(deliveredAt!) : null,
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'status': status.name,
      'isDeleted': isDeleted,
      'deletedFor': deletedFor,
      
    };
  }

  factory MessageEntity.fromMap(Map<String, dynamic> map) {
    return MessageEntity(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      text: map['text'],
      imageUrl: map['imageUrl'],
      audioUrl: map['audioUrl'],
      audioDuration: map['audioDuration'],
      type: MessageType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => MessageType.text,
      ),
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      deliveredAt: map['deliveredAt'] != null
          ? (map['deliveredAt'] as Timestamp).toDate()
          : null,
      readAt: map['readAt'] != null
          ? (map['readAt'] as Timestamp).toDate()
          : null,
      status: map['status'] != null
          ? MessageStatus.values.firstWhere(
              (e) => e.name == map['status'],
              orElse: () => MessageStatus.sent,
            )
          : MessageStatus.sent,
      isDeleted: map['isDeleted'] ?? false,
      deletedFor: List<String>.from(map['deletedFor'] ?? []),
      localFilePath: null, 
    );
  }

  MessageEntity copyWith({
    MessageStatus? status,
    bool? isDeleted,
    List<String>? deletedFor,
    DateTime? deliveredAt,
    DateTime? readAt,
    String? localFilePath,
  }) {
    return MessageEntity(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      text: text,
      imageUrl: imageUrl,
      audioUrl: audioUrl,
      audioDuration: audioDuration,
      type: type,
      timestamp: timestamp,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      readAt: readAt ?? this.readAt,
      status: status ?? this.status,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedFor: deletedFor ?? this.deletedFor,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }
}
