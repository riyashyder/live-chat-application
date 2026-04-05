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
import 'package:chat_app/features/chat/presentation/screens/full_image_screen.dart';
import 'package:chat_app/features/chat/presentation/screens/message_info_screen.dart';
import 'package:chat_app/core/widgets/shimmer_loading.dart';

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
    // Mark messages as read when opening chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chatActionsProvider.notifier).markAsRead(widget.chatId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Stop typing indicator when leaving - wrap in try-catch as ref might be defunct
    try {
      ref.read(chatActionsProvider.notifier).onTypingChanged(widget.chatId, '');
    } catch (_) {
      // Ignore if already disposed or defunct
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
          // Messages list
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
                data: (messages) {
                  // Mark new messages as read
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

                  return ListView.builder(
                    key: const ValueKey('messages_list'),
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: messages.length +
                        (typingAsync.valueOrNull == true ? 1 : 0),
                    itemBuilder: (context, index) {
                    // Show typing indicator at the top (index 0 when reversed)
                    if (typingAsync.valueOrNull == true && index == 0) {
                      return const TypingIndicator();
                    }

                    final msgIndex =
                        typingAsync.valueOrNull == true ? index - 1 : index;
                    final message = messages[msgIndex];
                    final isMe = message.senderId == currentUserId;

                    // Show tail for first message or when sender changes
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
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
          // Input bar
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
          imageUrl: message.imageUrl!,
          heroTag: 'image_${message.id}',
        ),
        transitionsBuilder: (context, anim, secondaryAnim, child) {
          return FadeTransition(opacity: anim, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}
