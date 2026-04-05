import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chat_app/core/theme/app_colors.dart';
import 'package:chat_app/core/widgets/avatar_widget.dart';
import 'package:chat_app/core/utils/date_formatter.dart';
import 'package:chat_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:chat_app/features/auth/domain/entities/user_entity.dart';
import 'package:chat_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:chat_app/features/chat/presentation/providers/chat_provider.dart';
import 'package:chat_app/features/chat/domain/entities/chat_entity.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';
import 'package:chat_app/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:chat_app/features/chat/presentation/screens/user_search_screen.dart';
import 'package:chat_app/features/chat/presentation/screens/full_image_screen.dart';
import 'package:chat_app/core/widgets/shimmer_loading.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(chatsStreamProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            onPressed: () {
              final currentMode = ref.read(themeModeProvider);
              ref.read(themeModeProvider.notifier).state =
                  currentMode == ThemeMode.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
            },
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: chatsAsync.when(
          loading: () => const ChatListShimmer(key: ValueKey('shimmer')),
          error: (e, _) => Center(
            key: const ValueKey('error'),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text('Error loading chats',
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text(e.toString(),
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          data: (chats) {
            // Avoid flickering "No conversations" if we are still refreshing
            // but have an empty list (likely initial cache miss or transition)
            if (chats.isEmpty &&
                (chatsAsync.isRefreshing || chatsAsync.isLoading)) {
              return const ChatListShimmer(key: ValueKey('shimmer_refreshing'));
            }

            if (chats.isEmpty) {
              return Center(
                key: const ValueKey('empty'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No conversations yet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Start a new chat to connect',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ).animate().fadeIn();
            }

            return ListView.builder(
              key: const ValueKey('list'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                return _ChatTile(
                  chat: chat,
                  currentUserId: currentUserId ?? '',
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserSearchScreen()),
        ),
        child: const Icon(Icons.chat_rounded),
      ),
    );
  }
}

class _ChatTile extends ConsumerWidget {
  final ChatEntity chat;
  final String currentUserId;

  const _ChatTile({
    required this.chat,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUserId = chat.getOtherParticipantId(currentUserId);
    final userAsync = ref.watch(userByIdProvider(otherUserId));
    final unreadCount = chat.getUnreadCount(currentUserId);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lastMessageAsync = ref.watch(lastMessageStreamProvider(chat.chatId));

    return userAsync.when(
      loading: () => const SizedBox(height: 72),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        if (unreadCount > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(chatActionsProvider.notifier).markAsDelivered(chat.chatId);
          });
        }

        return Dismissible(
          key: Key(chat.chatId),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: AppColors.error,
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            return await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Chat'),
                content:
                    const Text('Are you sure you want to delete this chat?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Delete',
                        style: TextStyle(color: AppColors.error)),
                  ),
                ],
              ),
            );
          },
          child: InkWell(
            onTap: () => _openChat(context, user),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  AvatarWidget(
                    imageUrl: user.profileImageUrl,
                    name: user.name,
                    radius: 28,
                    showOnlineIndicator: true,
                    isOnline: user.isOnline,
                    heroTag: 'avatar_${chat.chatId}',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullImageScreen(
                            imageUrl: user.profileImageUrl,
                            heroTag: 'avatar_${chat.chatId}',
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (chat.lastMessageTime != null)
                              Text(
                                DateFormatter.formatChatListTime(
                                    chat.lastMessageTime!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: unreadCount > 0
                                      ? AppColors.primary
                                      : (isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary),
                                  fontWeight: unreadCount > 0
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (chat.lastMessageSenderId == currentUserId)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.done_all,
                                  size: 16,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                _getLastMessagePreview(
                                    chat,
                                    lastMessageAsync.valueOrNull,
                                    lastMessageAsync.hasValue),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                  fontWeight: unreadCount > 0
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  unreadCount > 99
                                      ? '99+'
                                      : unreadCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getLastMessagePreview(
      ChatEntity chat, MessageEntity? msg, bool isLoaded) {
    // If we have successfully loaded the specific last message for this user, follow it
    if (isLoaded) {
      if (msg == null) return 'Start a conversation';
      if (msg.isDeleted) return '🚫 This message was deleted';
      if (msg.type == MessageType.image) return '📷 Image';
      if (msg.type == MessageType.audio) return '🎤 Audio';
      return msg.text ?? '';
    }

    // Fallback while loading or if stream is unavailable
    if (chat.lastMessage.isEmpty) return 'Start a conversation';

    // Check if the chat was cleared after the last message was sent
    final clearedAt = chat.clearedAt['clearedAt_$currentUserId'];
    if (clearedAt != null && chat.lastMessageTime != null) {
      if (chat.lastMessageTime!.isBefore(clearedAt)) {
        return 'Start a conversation';
      }
    }

    return chat.lastMessage;
  }

  void _openChat(BuildContext context, UserEntity user) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ChatDetailScreen(
          otherUser: user,
          chatId: chat.chatId,
        ),
        transitionsBuilder: (context, anim, secondaryAnim, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}
