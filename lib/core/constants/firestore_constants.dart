class FirestoreConstants {
  // Collections
  static const String usersCollection = 'users';
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';

  // User fields
  static const String uid = 'uid';
  static const String name = 'name';
  static const String email = 'email';
  static const String profileImageUrl = 'profileImageUrl';
  static const String isOnline = 'isOnline';
  static const String lastSeen = 'lastSeen';
  static const String statusText = 'statusText';
  static const String createdAt = 'createdAt';

  // Chat fields
  static const String participants = 'participants';
  static const String lastMessage = 'lastMessage';
  static const String lastMessageTime = 'lastMessageTime';
  static const String lastMessageSenderId = 'lastMessageSenderId';
  static const String lastMessageType = 'lastMessageType';

  // Message fields
  static const String senderId = 'senderId';
  static const String receiverId = 'receiverId';
  static const String text = 'text';
  static const String imageUrl = 'imageUrl';
  static const String audioUrl = 'audioUrl';
  static const String audioDuration = 'audioDuration';
  static const String type = 'type';
  static const String timestamp = 'timestamp';
  static const String status = 'status';

  // Message types
  static const String messageTypeText = 'text';
  static const String messageTypeImage = 'image';
  static const String messageTypeAudio = 'audio';

  // Message status
  static const String statusSent = 'sent';
  static const String statusDelivered = 'delivered';
  static const String statusRead = 'read';

  // Storage paths
  static const String profileImagesPath = 'profile_images';
  static const String chatImagesPath = 'chat_images';
  static const String chatAudioPath = 'chat_audio';
}
