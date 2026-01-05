import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

class CloudinaryService {
  static const String _cloudName = 'dya7urmkw';
  static const String _uploadPreset = 'stayhub_preset'; 

  final CloudinaryPublic _cloudinary;

  CloudinaryService() : _cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);

  Future<String?> uploadProfilePicture(XFile xFile) async {
    try {
      final bytes = await xFile.readAsBytes();
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromByteData(
          ByteData.view(bytes.buffer),
          resourceType: CloudinaryResourceType.Image,
          identifier: xFile.name,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      debugPrint("Cloudinary Upload Error: $e");
      return null;
    }
  }

  Future<String?> uploadVideo(XFile xFile) async {
    try {
      final bytes = await xFile.readAsBytes();
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromByteData(
          ByteData.view(bytes.buffer),
          resourceType: CloudinaryResourceType.Video,
          identifier: xFile.name,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      debugPrint("Cloudinary Video Upload Error: $e");
      return null;
    }
  }
}
