import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:chat_app/core/theme/app_colors.dart';
import 'package:chat_app/core/utils/date_formatter.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';

class MessageBubble extends StatelessWidget {
  final MessageEntity message;
  final bool isMe;
  final bool showTail;
  final VoidCallback? onImageTap;
  final VoidCallback? onLongPress;
  final Widget? audioPlayer;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showTail = true,
    this.onImageTap,
    this.onLongPress,
    this.audioPlayer,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bubbleColor = isMe
        ? (isDark ? AppColors.senderBubbleDark : AppColors.senderBubbleLight)
        : (isDark ? AppColors.receiverBubbleDark : AppColors.receiverBubbleLight);

    final textColor = isMe
        ? Colors.white
        : (isDark ? AppColors.darkText : AppColors.lightText);

    final timeColor = isMe
        ? Colors.white.withValues(alpha: 0.7)
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: onLongPress,
                child: Opacity(
                  opacity: message.isDeleted ? 0.6 : 1.0,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: message.type == MessageType.image && !message.isDeleted ? 4 : 14,
                      vertical: message.type == MessageType.image && !message.isDeleted ? 4 : 10,
                    ),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isMe ? 20 : 0),
                          bottomRight: Radius.circular(isMe ? 0 : 20),
                        ),
                        border: !isMe && isDark
                            ? Border.all(
                                color: Colors.white.withValues(alpha: 0.05),
                                width: 0.5,
                              )
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        gradient: !message.isDeleted
                            ? isMe
                                ? LinearGradient(
                                    colors: [
                                      bubbleColor,
                                      bubbleColor.withValues(alpha: 0.8),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  )
                                : isDark
                                    ? LinearGradient(
                                        colors: [
                                          bubbleColor,
                                          bubbleColor.withValues(alpha: 0.9),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      )
                                    : null
                            : null,
                      ),
                    child: _buildContent(context, textColor, timeColor),
                  ).animate().fadeIn(duration: 300.ms, curve: Curves.easeOut).slideX(
                        begin: isMe ? 0.2 : -0.2,
                        end: 0,
                        duration: 400.ms,
                        curve: Curves.easeOutCubic,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, Color textColor, Color timeColor) {
    if (message.isDeleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 14, color: textColor.withValues(alpha: 0.6)),
          const SizedBox(width: 8),
          Text(
            'This message was deleted',
            style: TextStyle(
              color: textColor.withValues(alpha: 0.6),
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    switch (message.type) {
      case MessageType.text:
        return _buildTextContent(textColor, timeColor);
      case MessageType.image:
        return _buildImageContent(context, timeColor);
      case MessageType.audio:
        return _buildAudioContent(timeColor);
    }
  }

  Widget _buildTextContent(Color textColor, Color timeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          message.text ?? '',
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormatter.formatMessageTime(message.timestamp),
              style: TextStyle(
                color: timeColor,
                fontSize: 11,
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 4),
              _buildStatusIcon(timeColor),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildImageContent(BuildContext context, Color timeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: onImageTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Hero(
                  tag: 'image_${message.id}',
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: message.imageUrl != null
                        ? Image.network(
                            message.imageUrl!,
                            width: 220,
                            height: 220,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 220,
                            height: 220,
                            color: Colors.grey.withValues(alpha: 0.2),
                          ),
                  ),
                ),
                Container(
                  width: 220,
                  height: 220,
                  color: Colors.black.withValues(alpha: 0.2),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_off_outlined, color: Colors.white, size: 32),
                        SizedBox(height: 8),
                        Text(
                          'Tap to View',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormatter.formatMessageTime(message.timestamp),
                style: TextStyle(color: timeColor, fontSize: 11),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                _buildStatusIcon(timeColor),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAudioContent(Color timeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        audioPlayer ?? const SizedBox.shrink(),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormatter.formatMessageTime(message.timestamp),
                style: TextStyle(color: timeColor, fontSize: 11),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                _buildStatusIcon(timeColor),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcon(Color color) {
    switch (message.status) {
      case MessageStatus.sent:
        return Icon(Icons.check, size: 14, color: color);
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: color);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 14, color: AppColors.accent);
    }
  }
}
