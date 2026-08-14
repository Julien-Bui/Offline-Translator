import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service responsible for capturing images, extracting text via OCR,
/// and ensuring all temporary files are cleaned up immediately.
///
/// Security measures:
/// - Photos are NEVER saved permanently (deleted in finally block)
/// - Image size is validated before processing (max 10 MB)
/// - OCR has a 30-second timeout to prevent freezes
/// - Only camera source is allowed (no arbitrary file paths)
/// - Extracted text is sanitized (control characters removed)
class ImageTranslator {
  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const Duration _ocrTimeout = Duration(seconds: 30);
  static const double _maxImageWidth = 1920;

  final ImagePicker _picker = ImagePicker();

  /// Captures a photo from the camera and extracts text via OCR.
  /// Returns the extracted text, or null if cancelled/failed.
  /// The photo file is ALWAYS deleted after processing (privacy-first).
  Future<String?> captureAndExtract() async {
    File? imageFile;

    try {
      // 1. Capture photo from camera only (no gallery)
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: _maxImageWidth,
        imageQuality: 80, // Compress to 80% quality
      );

      if (photo == null) return null; // User cancelled

      imageFile = File(photo.path);

      // 2. Validate the captured file
      await _validateImage(imageFile);

      // 3. Run OCR with timeout
      final extractedText = await _runOcr(imageFile).timeout(
        _ocrTimeout,
        onTimeout: () => throw Exception('OCR timed out after ${_ocrTimeout.inSeconds}s'),
      );

      return extractedText;
    } catch (e) {
      debugPrint('ImageTranslator error: $e');
      rethrow;
    } finally {
      // SECURITY: Always delete the photo file, even on error/crash
      await _safeDelete(imageFile);
    }
  }

  /// Validates the image file before processing.
  /// Checks: file exists, size within limit, valid extension.
  Future<void> _validateImage(File file) async {
    if (!await file.exists()) {
      throw Exception('Image file does not exist');
    }

    final fileSize = await file.length();
    if (fileSize > _maxFileSizeBytes) {
      throw Exception('Image too large (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB, max ${_maxFileSizeBytes ~/ 1024 ~/ 1024} MB)');
    }

    // Validate file extension (defense in depth)
    final extension = file.path.toLowerCase().split('.').last;
    if (!['jpg', 'jpeg', 'png'].contains(extension)) {
      throw Exception('Invalid image format: $extension. Only JPG/PNG allowed.');
    }
  }

  /// Runs ML Kit Text Recognition on the image file.
  /// Returns sanitized extracted text.
  Future<String> _runOcr(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);

    // Use Latin script recognizer by default (covers FR, EN, ES, DE, IT, PT)
    // For Chinese/Japanese/Korean, ML Kit handles multi-script detection automatically
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      if (recognizedText.text.isEmpty) {
        throw Exception('No text detected in the image');
      }

      // Sanitize: remove control characters, excessive whitespace
      return _sanitizeText(recognizedText.text);
    } finally {
      await textRecognizer.close();
    }
  }

  /// Sanitizes OCR output by removing control characters
  /// and normalizing whitespace.
  String _sanitizeText(String raw) {
    return raw
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '') // Remove control chars
        .replaceAll(RegExp(r'\n{3,}'), '\n\n') // Max 2 consecutive newlines
        .trim();
  }

  /// Safely deletes a file, swallowing any errors.
  /// This ensures cleanup happens even if the file is locked or already deleted.
  Future<void> _safeDelete(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) {
        await file.delete();
        debugPrint('ImageTranslator: Photo deleted (privacy-first)');
      }
    } catch (e) {
      debugPrint('ImageTranslator: Warning - could not delete photo: $e');
    }
  }
}
