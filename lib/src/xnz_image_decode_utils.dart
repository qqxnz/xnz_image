import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

class XNZImageDecodeUtils {
  const XNZImageDecodeUtils._();

  static Future<ui.Codec> decodeChecked({
    required Uint8List data,
    required ImageDecoderCallback decode,
    required String source,
  }) async {
    if (data.isEmpty) {
      throw StateError('Empty image bytes: $source');
    }
    if (!isLikelyImageData(data)) {
      throw StateError(
        'Response is not likely binary image data: $source, '
        'prefix:${samplePrefix(data)}',
      );
    }
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(
      data,
    );
    return decode(buffer);
  }

  static bool isLikelyImageData(Uint8List data) {
    if (data.length < 2) return false;
    final b0 = data[0];
    final b1 = data[1];
    if (b0 == 0xFF && b1 == 0xD8) return true; // jpeg
    if (data.length >= 8 &&
        data[0] == 0x89 &&
        data[1] == 0x50 &&
        data[2] == 0x4E &&
        data[3] == 0x47 &&
        data[4] == 0x0D &&
        data[5] == 0x0A &&
        data[6] == 0x1A &&
        data[7] == 0x0A) {
      return true; // png
    }
    if (data.length >= 6) {
      final gif87a = data[0] == 0x47 &&
          data[1] == 0x49 &&
          data[2] == 0x46 &&
          data[3] == 0x38 &&
          data[4] == 0x37 &&
          data[5] == 0x61;
      final gif89a = data[0] == 0x47 &&
          data[1] == 0x49 &&
          data[2] == 0x46 &&
          data[3] == 0x38 &&
          data[4] == 0x39 &&
          data[5] == 0x61;
      if (gif87a || gif89a) return true;
    }
    if (data.length >= 12 &&
        data[0] == 0x52 &&
        data[1] == 0x49 &&
        data[2] == 0x46 &&
        data[3] == 0x46 &&
        data[8] == 0x57 &&
        data[9] == 0x45 &&
        data[10] == 0x42 &&
        data[11] == 0x50) {
      return true; // webp
    }
    if (data.length >= 12 &&
        data[4] == 0x66 &&
        data[5] == 0x74 &&
        data[6] == 0x79 &&
        data[7] == 0x70) {
      return true; // avif/heic/other ftyp container
    }
    final prefix = samplePrefix(data).toLowerCase();
    if (prefix.startsWith('<!doctype html') ||
        prefix.startsWith('<html') ||
        prefix.startsWith('<?xml') ||
        prefix.startsWith('<svg') ||
        prefix.startsWith('{') ||
        prefix.startsWith('[')) {
      return false;
    }
    // Unknown binary payload: keep it decode-able by Flutter instead of hard failing.
    return true;
  }

  static String samplePrefix(Uint8List data) {
    final sampleLen = data.length < 64 ? data.length : 64;
    final bytes = data.sublist(0, sampleLen);
    final chars = bytes
        .map((b) => (b >= 32 && b <= 126) ? String.fromCharCode(b) : '.')
        .join();
    return chars.trim();
  }
}
