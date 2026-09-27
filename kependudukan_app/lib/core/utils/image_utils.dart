import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Utility class for image processing operations
class ImageUtils {
  /// Compress image file
  static Future<File> compressImage(File imageFile,
      {int quality = 80, int minWidth = 1024, int minHeight = 1024}) async {
    try {
      final filePath = imageFile.absolute.path;

      // Compress the image
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        filePath,
        quality: quality,
        minWidth: minWidth,
        minHeight: minHeight,
      );

      if (compressedBytes == null) {
        // Return original file if compression fails
        return imageFile;
      }

      // Create compressed file
      final compressedFile = File('${filePath}_compressed.jpg');
      await compressedFile.writeAsBytes(compressedBytes);

      return compressedFile;
    } catch (e) {
      // Return original file on error
      return imageFile;
    }
  }

  /// Process image: compress only (WebP conversion disabled for stability)
  static Future<File> processImage(File imageFile,
      {int quality = 80, bool convertToWebP = false}) async {
    try {
      // Compress the image only for now
      final compressedFile = await compressImage(imageFile, quality: quality);
      return compressedFile;
    } catch (e) {
      // Return original file if processing fails
      return imageFile;
    }
  }
}
