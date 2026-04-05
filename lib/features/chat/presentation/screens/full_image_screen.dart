import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FullImageScreen extends StatelessWidget {
  final String imageUrl;
  final String heroTag;
  final String? localFilePath;

  const FullImageScreen({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.localFilePath,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.isNotEmpty;
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(hasImage ? '' : 'No Profile Picture'),
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: hasImage || localFilePath != null
              ? PhotoView(
                  imageProvider: localFilePath != null 
                    ? FileImage(File(localFilePath!)) as ImageProvider
                    : CachedNetworkImageProvider(imageUrl),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  backgroundDecoration: const BoxDecoration(color: Colors.black),
                  loadingBuilder: (_, event) => Center(
                    child: CircularProgressIndicator(
                      value: event != null && event.expectedTotalBytes != null
                          ? event.cumulativeBytesLoaded / event.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 150,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Profile Picture',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
