import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';

class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double radius;
  final bool showOnlineIndicator;
  final bool isOnline;
  final String? heroTag;
  final VoidCallback? onTap;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    required this.name,
    this.radius = 24,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.heroTag,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Hero(
            tag: heroTag ?? 'avatar_$name',
            child: CircleAvatar(
              radius: radius,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              backgroundImage:
                  imageUrl != null && imageUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(imageUrl!)
                      : null,
              child:
                  imageUrl == null || imageUrl!.isEmpty
                      ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: radius * 0.8,
                        ),
                      )
                      : null,
            ),
          ),
          if (showOnlineIndicator)
            Positioned(
              bottom: 0,
              right: 0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: radius * 0.5,
                height: radius * 0.5,
                decoration: BoxDecoration(
                  color: isOnline ? AppColors.online : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                  boxShadow:
                      isOnline
                          ? [
                            BoxShadow(
                              color: AppColors.online.withValues(alpha: 0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                          : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
