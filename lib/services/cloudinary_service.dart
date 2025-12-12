import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  // Replaced with your actual Cloudinary credentials
  static const String _cloudName = 'dya7urmkw';
  static const String _uploadPreset = 'stayhub_preset'; 

  final CloudinaryPublic _cloudinary;

  CloudinaryService() : _cloudinary = CloudinaryPublic(_cloudName, _uploadPreset, cache: false);

  Future<String?> uploadProfilePicture(File file) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(file.path, resourceType: CloudinaryResourceType.Image),
      );
      return response.secureUrl;
    } catch (e) {
      print("Cloudinary Upload Error: $e");
      return null;
    }
  }
}
