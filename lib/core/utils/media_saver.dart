import 'dart:io';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class MediaSaver {
  static Future<bool> saveImage(String? imageUrl, String? localPath) async {
    try {
      print(
          'MediaSaver: Starting save process. URL: $imageUrl, Local: $localPath');

      String? pathToSave;

      // Explicitly check for gallery permissions
      bool hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        print('MediaSaver: Requesting gallery access...');
        hasAccess = await Gal.requestAccess();
      }

      if (!hasAccess) {
        print('MediaSaver: Permission denied by user.');
        return false;
      }

      if (localPath != null && await File(localPath).exists()) {
        print('MediaSaver: Using existing local file: $localPath');
        pathToSave = localPath;
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        // Ensure HTTPS
        final downloadUrl = imageUrl.startsWith('http://')
            ? imageUrl.replaceFirst('http://', 'https://')
            : imageUrl;

        print('MediaSaver: Downloading from URL: $downloadUrl');

        final tempDir = await getTemporaryDirectory();
        final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
        pathToSave = '${tempDir.path}/$fileName';

        await Dio().download(downloadUrl, pathToSave);
        print('MediaSaver: Download complete: $pathToSave');
      }

      if (pathToSave != null && await File(pathToSave).exists()) {
        print('MediaSaver: Saving to gallery via Gal...');
        await Gal.putImage(pathToSave);
        print('MediaSaver: Successfully saved to gallery!');
        return true;
      } else {
        print('MediaSaver: No valid path to save or file does not exist.');
        return false;
      }
    } catch (e) {
      print('MediaSaver Error: $e');
      if (e is DioException) {
        print('Dio error type: ${e.type}, message: ${e.message}');
      }
      return false;
    }
  }
}
