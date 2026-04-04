import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:chat_app/core/theme/app_colors.dart';
import 'package:chat_app/features/chat/domain/entities/message_entity.dart';

class MessageInfoScreen extends StatelessWidget {
  final MessageEntity message;

  const MessageInfoScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Info'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMessagePreview(isDark),
            const SizedBox(height: 32),
            const Text(
              'Message Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatusItem(
              icon: Icons.done,
              label: 'Sent',
              time: message.timestamp,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            _buildDivider(),
            _buildStatusItem(
              icon: Icons.done_all,
              label: 'Delivered',
              time: message.deliveredAt,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            _buildDivider(),
            _buildStatusItem(
              icon: Icons.done_all,
              label: 'Read',
              time: message.readAt,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagePreview(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.type == MessageType.text)
            Text(
              message.text ?? '',
              style: const TextStyle(fontSize: 16),
            )
          else if (message.type == MessageType.image)
            const Row(
              children: [
                Icon(Icons.image, size: 20),
                SizedBox(width: 8),
                Text('Image', style: TextStyle(fontSize: 16)),
              ],
            )
          else
            const Row(
              children: [
                Icon(Icons.mic, size: 20),
                SizedBox(width: 8),
                Text('Audio Message', style: TextStyle(fontSize: 16)),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            DateFormat('MMM d, h:mm a').format(message.timestamp),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required DateTime? time,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: time != null ? color : Colors.grey.withValues(alpha: 0.3), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: time != null ? null : Colors.grey,
                  ),
                ),
                if (time != null)
                  Text(
                    DateFormat('MMM d, h:mm a').format(time),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  )
                else
                  const Text(
                    'Pending...',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 40),
      height: 20,
      width: 1,
      color: Colors.grey.withValues(alpha: 0.2),
    );
  }
}
