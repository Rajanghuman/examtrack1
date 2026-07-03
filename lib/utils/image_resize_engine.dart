import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Core image-processing engine for the Photo/Signature Resizer
/// feature. Pure Dart, no UI dependencies — takes raw image bytes
/// and a target spec, returns processed bytes ready to save.
///
/// This is intentionally NOT AI-powered: resizing to an exact
/// width/height and hitting a target file-size range is a solved,
/// deterministic problem (crop + scale + iteratively adjust JPEG
/// quality), so there's no benefit to involving a model here —
/// it would only add latency and a network dependency for a task
/// that's faster and more reliable done locally.
class ImageResizeEngine {
  /// Result of a resize operation, including the actual stats
  /// achieved (so the UI can show "198x229px, 34KB" feedback).
  static Future<ResizeResult> resize({
    required Uint8List sourceBytes,
    required int targetWidth,
    required int targetHeight,
    required int minKB,
    required int maxKB,
  }) async {
    // Decode the source image. Returns null if the format isn't
    // recognized (corrupted file, unsupported format, etc.)
    final decoded = img.decodeImage(sourceBytes);
    if (decoded == null) {
      return ResizeResult.failure('Could not read this image. Try a different photo.');
    }

    // ── Step 1: Center-crop to match the target aspect ratio ────
    // This runs even if the user already manually cropped via
    // image_cropper (in which case the aspect ratio should already
    // match closely, so this crop is effectively a no-op safety net
    // that just trims any small rounding mismatch).
    final cropped = _centerCropToAspectRatio(decoded, targetWidth, targetHeight);

    // ── Step 2: Resize to the exact target pixel dimensions ─────
    final resized = img.copyResize(
      cropped,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.average,
    );

    // ── Step 3: Iteratively find a JPEG quality that lands the
    // file size inside [minKB, maxKB] ─────────────────────────────
    final compressed = _compressToTargetSize(resized, minKB, maxKB);

    return ResizeResult.success(
      bytes: compressed.bytes,
      actualWidth: targetWidth,
      actualHeight: targetHeight,
      actualSizeKB: compressed.sizeKB,
      qualityUsed: compressed.quality,
      hitTargetRange: compressed.sizeKB >= minKB && compressed.sizeKB <= maxKB,
    );
  }

  // ── Center crop helper ────────────────────────────────────────
  // Crops the largest possible rectangle matching the target aspect
  // ratio from the center of the source image (mirrors BoxFit.cover
  // behavior). If the user already cropped manually, this is a
  // near-no-op since the aspect ratio will already match.
  static img.Image _centerCropToAspectRatio(
      img.Image source,
      int targetWidth,
      int targetHeight,
      ) {
    final targetRatio = targetWidth / targetHeight;
    final sourceRatio = source.width / source.height;

    int cropWidth, cropHeight;
    if (sourceRatio > targetRatio) {
      // Source is wider than target ratio — crop the sides.
      cropHeight = source.height;
      cropWidth = (source.height * targetRatio).round();
    } else {
      // Source is taller than (or equal to) target ratio — crop top/bottom.
      cropWidth = source.width;
      cropHeight = (source.width / targetRatio).round();
    }

    final offsetX = ((source.width - cropWidth) / 2).round();
    final offsetY = ((source.height - cropHeight) / 2).round();

    return img.copyCrop(
      source,
      x: offsetX,
      y: offsetY,
      width: cropWidth,
      height: cropHeight,
    );
  }

  // ── Quality-search compression loop ─────────────────────────────
  // Binary-search-style approach: try a quality level, check the
  // resulting size, adjust up or down. JPEG quality and file size
  // have a roughly monotonic (if not perfectly linear) relationship,
  // so this converges quickly — typically within 5-8 attempts.
  static _CompressedResult _compressToTargetSize(
      img.Image image,
      int minKB,
      int maxKB,
      ) {
    int low = 5;
    int high = 100;
    Uint8List? bestBytes;
    int bestQuality = 50;
    int bestSizeKB = 0;

    // First, try a reasonable starting guess.
    int quality = 75;

    for (int attempt = 0; attempt < 10; attempt++) {
      final bytes = Uint8List.fromList(img.encodeJpg(image, quality: quality));
      final sizeKB = (bytes.length / 1024).round();

      bestBytes = bytes;
      bestQuality = quality;
      bestSizeKB = sizeKB;

      if (sizeKB >= minKB && sizeKB <= maxKB) {
        // Hit the target range — done.
        break;
      }

      if (sizeKB > maxKB) {
        // Too big — need lower quality (more compression).
        high = quality - 1;
        quality = ((low + high) / 2).round();
      } else {
        // Too small — need higher quality (less compression).
        low = quality + 1;
        quality = ((low + high) / 2).round();
      }

      if (low > high) {
        // Search space exhausted without landing exactly in range.
        // This can happen for very small target KB ranges relative
        // to image content (e.g. a highly detailed photo that can't
        // get small enough even at quality=5, or a target range so
        // tight it falls between two achievable quality steps).
        // bestBytes holds the closest attempt found so far.
        break;
      }
    }

    return _CompressedResult(
      bytes: bestBytes!,
      quality: bestQuality,
      sizeKB: bestSizeKB,
    );
  }
}

class _CompressedResult {
  final Uint8List bytes;
  final int quality;
  final int sizeKB;
  _CompressedResult({required this.bytes, required this.quality, required this.sizeKB});
}

/// Outcome of a resize operation, returned to the UI layer.
class ResizeResult {
  final bool isSuccess;
  final String? errorMessage;
  final Uint8List? bytes;
  final int? actualWidth;
  final int? actualHeight;
  final int? actualSizeKB;
  final int? qualityUsed;
  final bool? hitTargetRange;

  ResizeResult._({
    required this.isSuccess,
    this.errorMessage,
    this.bytes,
    this.actualWidth,
    this.actualHeight,
    this.actualSizeKB,
    this.qualityUsed,
    this.hitTargetRange,
  });

  factory ResizeResult.success({
    required Uint8List bytes,
    required int actualWidth,
    required int actualHeight,
    required int actualSizeKB,
    required int qualityUsed,
    required bool hitTargetRange,
  }) {
    return ResizeResult._(
      isSuccess: true,
      bytes: bytes,
      actualWidth: actualWidth,
      actualHeight: actualHeight,
      actualSizeKB: actualSizeKB,
      qualityUsed: qualityUsed,
      hitTargetRange: hitTargetRange,
    );
  }

  factory ResizeResult.failure(String message) {
    return ResizeResult._(isSuccess: false, errorMessage: message);
  }
}

/// Helper to read an image File into bytes (used by the screen
/// after image_picker / image_cropper return a file path).
Future<Uint8List> readImageBytes(String path) async {
  return File(path).readAsBytes();
}