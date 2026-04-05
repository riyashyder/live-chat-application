import 'dart:io';
import 'package:dio/dio.dart';
import 'package:chat_app/core/constants/cloudinary_constants.dart';

class CloudinaryService {
  final _dio = Dio();

  Future<String?> uploadFile({
    required File file,
    required String folder,
    String? resourceType, // 'image', 'video' (for audio), 'raw'
  }) async {
    try {
      final String url =
          'https://api.cloudinary.com/v1_1/${CloudinaryConstants.cloudName}/upload';

  
      final effectiveResourceType = resourceType ?? 'auto';

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path),
        'upload_preset': CloudinaryConstants.uploadPreset,
        'folder': folder,
        'resource_type': effectiveResourceType,
      });

      final response = await _dio.post(
        url,
        data: formData,
      );

      if (response.statusCode == 200) {
        return response.data['secure_url'] as String;
      }
      return null;
    } catch (e) {
     
      return null;
    }
  }

  Future<String?> uploadImage(File file, String folder) async {
    return uploadFile(file: file, folder: folder, resourceType: 'image');
  }

  Future<String?> uploadAudio(File file, String folder) async {
    
    return uploadFile(file: file, folder: folder, resourceType: 'video');
  }
}
