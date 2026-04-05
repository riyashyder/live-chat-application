import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chat_app/core/theme/app_colors.dart';
import 'package:chat_app/core/widgets/avatar_widget.dart';
import 'package:chat_app/core/utils/date_formatter.dart';
import 'package:chat_app/features/auth/domain/entities/user_entity.dart';
import 'package:chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:chat_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/presentation/widgets/message_bubble.dart';
import 'package:chat_app/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:chat_app/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:chat_app/features/chat/presentation/widgets/audio_player_widget.dart';
import 'package:chat_app/features/chat/presentation/screens/full_image_screen.dart';
import 'package:chat_app/features/chat/presentation/screens/message_info_screen.dart';
import 'package:chat_app/core/widgets/shimmer_loading.dart';
import 'package:chat_app/core/utils/media_saver.dart';

class ChatDetailScreen extends ConsumerStatefulWidget {
  final UserEntity otherUser;
  final String chatId;

  const ChatDetailScreen({
    super.key,
    required this.otherUser,
    required this.chatId,
  });

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chatActionsProvider.notifier).markAsRead(widget.chatId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    
    try {
      ref.read(chatActionsProvider.notifier).onTypingChanged(widget.chatId, '');
    } catch (_) {
      
    }
    super.dispose();
  }

  void _showClearChatDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Text('Clear Chat?'),
          ],
        ),
        content: const Text(
          'This will remove all messages from this conversation for you. This action is irreversible.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style:
                    TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(chatActionsProvider.notifier).clearChat(widget.chatId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Clear All',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesStreamProvider(widget.chatId));
    final otherUserStream = ref.watch(userByIdProvider(widget.otherUser.uid));
    final currentUserId = ref.watch(currentUserIdProvider);
    final typingAsync = ref.watch(typingStatusProvider((
      chatId: widget.chatId,
      otherUserId: widget.otherUser.uid,
    )));
    final chatActionsState = ref.watch(chatActionsProvider);
    final pendingMessages = chatActionsState.pendingMessages[widget.chatId] ?? [];
    final displayUser = otherUserStream.valueOrNull ?? widget.otherUser;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 32,
        title: Row(
          children: [
            AvatarWidget(
              imageUrl: displayUser.profileImageUrl,
              name: displayUser.name,
              radius: 20,
              showOnlineIndicator: true,
              isOnline: displayUser.isOnline,
              heroTag: 'avatar_${widget.chatId}',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullImageScreen(
                      imageUrl: displayUser.profileImageUrl,
                      heroTag: 'avatar_${widget.chatId}',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayUser.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    displayUser.isOnline
                        ? 'Online'
                        : displayUser.lastSeen != null
                            ? 'Last seen ${DateFormatter.formatLastSeen(displayUser.lastSeen)}'
                            : '',
                    style: TextStyle(
                      fontSize: 12,
                      color: displayUser.isOnline
                          ? AppColors.online
                          : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'clear_chat') {
                _showClearChatDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_chat',
                child: Text('Clear Chat'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: messagesAsync.when(
                loading: () => const ShimmerLoading(
                  key: ValueKey('messages_loading'),
                  isLoading: true,
                  child: MessageShimmer(),
                ),
                error: (e, _) => Center(
                  key: const ValueKey('messages_error'),
                  child: Text('Error: $e'),
                ),
                data: (firestoreMessages) {
                  
                  final Map<String, MessageEntity> messageMap = {};
                  
                  
                  for (final msg in firestoreMessages) {
                    messageMap[msg.id] = msg;
                  }
                  
                  
                  for (final pending in pendingMessages) {
                    if (!messageMap.containsKey(pending.id)) {
                      messageMap[pending.id] = pending;
                    }
                  }

                  final messages = messageMap.values.toList()
                    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                  
                  if (messages.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      ref
                          .read(chatActionsProvider.notifier)
                          .markAsRead(widget.chatId);
                    });
                  }

                  if (messages.isEmpty && (messagesAsync.isRefreshing || messagesAsync.isLoading)) {
                    return const ShimmerLoading(
                      key: ValueKey('messages_refreshing'),
                      isLoading: true,
                      child: MessageShimmer(),
                    );
                  }

                  if (messages.isEmpty) {
                    return _buildEmptyState(displayUser.name);
                  }

                  return ListView.builder(
                    key: const ValueKey('messages_list'),
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length +
                        (typingAsync.valueOrNull == true ? 1 : 0),
                    itemBuilder: (context, index) {
                    
                    if (typingAsync.valueOrNull == true && index == 0) {
                      return const TypingIndicator();
                    }

                    final msgIndex =
                        typingAsync.valueOrNull == true ? index - 1 : index;
                    final message = messages[msgIndex];
                    final isMe = message.senderId == currentUserId;

                    
                    final showTail = msgIndex == messages.length - 1 ||
                        messages[msgIndex + 1].senderId != message.senderId;

                    return Padding(
                      padding: EdgeInsets.only(
                        top: showTail ? 6 : 1,
                      ),
                      child: MessageBubble(
                        message: message,
                        isMe: isMe,
                        showTail: showTail,
                        onLongPress: () => _showMessageOptions(message),
                        onImageTap: message.type == MessageType.image
                            ? () => _openFullImage(message)
                            : null,
                        audioPlayer: message.type == MessageType.audio
                            ? AudioPlayerWidget(
                                audioUrl: message.audioUrl ?? message.localFilePath ?? '',
                                durationInSeconds: message.audioDuration,
                                isMe: isMe,
                                isLocal: message.audioUrl == null,
                              )
                            : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
          
          ChatInputBar(
            onSendText: (text) {
              ref.read(chatActionsProvider.notifier).sendTextMessage(
                    chatId: widget.chatId,
                    receiverId: widget.otherUser.uid,
                    text: text,
                  );
            },
            onSendImage: (File file) {
              ref.read(chatActionsProvider.notifier).sendImageMessage(
                    chatId: widget.chatId,
                    receiverId: widget.otherUser.uid,
                    imageFile: file,
                  );
            },
            onSendAudio: (File file, int duration) {
              ref.read(chatActionsProvider.notifier).sendAudioMessage(
                    chatId: widget.chatId,
                    receiverId: widget.otherUser.uid,
                    audioFile: file,
                    durationInSeconds: duration,
                  );
            },
            onTypingChanged: (text) {
              ref
                  .read(chatActionsProvider.notifier)
                  .onTypingChanged(widget.chatId, text);
            },
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(MessageEntity message) {
    if (message.isDeleted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.type == MessageType.image)
              ListTile(
                leading: const Icon(Icons.download_rounded, color: AppColors.primary),
                title: const Text('Save to Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final success = await MediaSaver.saveImage(message.imageUrl ?? '', message.localFilePath);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success ? 'Image saved to gallery!' : 'Failed to save image.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            if (message.senderId == ref.read(currentUserIdProvider))
              ListTile(
                leading: const Icon(Icons.info_outline_rounded,
                    color: AppColors.primary),
                title: const Text('Message Info'),
                onTap: () {
                  Navigator.pop(context);
                  _showMessageInfo(message);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.error),
              title: const Text('Delete Message'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteMessageDialog(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageInfo(MessageEntity message) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessageInfoScreen(message: message),
      ),
    );
  }

  void _showDeleteMessageDialog(MessageEntity message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('How would you like to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (message.senderId == ref.read(currentUserIdProvider))
            TextButton(
              onPressed: () {
                ref.read(chatActionsProvider.notifier).deleteMessage(
                      widget.chatId,
                      message.id,
                      forEveryone: true,
                    );
                Navigator.pop(context);
              },
              child: const Text('Delete for Everyone',
                  style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () {
              ref.read(chatActionsProvider.notifier).deleteMessage(
                    widget.chatId,
                    message.id,
                    forEveryone: false,
                  );
              Navigator.pop(context);
            },
            child: const Text('Delete for Me',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openFullImage(MessageEntity message) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullImageScreen(
          imageUrl: message.imageUrl ?? '',
          localFilePath: message.localFilePath,
          heroTag: 'image_${message.id}',
        ),
        transitionsBuilder: (context, anim, secondaryAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Widget _buildEmptyState(String userName) {
    return Center(
      key: const ValueKey('messages_empty'),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: 80,
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Say Hi to $userName! 👋',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start a conversation with a message\nor share something interesting.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[500],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
