import 'package:flutter/widgets.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

import 'package:xnz_image/src/animated/xnz_animated_bytes_fingerprint.dart';
import 'package:xnz_image/src/xnz_asset_image_provider.dart';
import 'package:xnz_image/src/xnz_file_image_provider.dart';
import 'package:xnz_image/src/xnz_memory_image_provider.dart';
import 'package:xnz_image/src/xnz_network_image_provider.dart';

/// Builds a cache key for animated image decode results.
String? xnzAnimatedCacheKeyForProvider(ImageProvider provider) {
  if (provider is XNZNetworkImageProvider) {
    final request = XNZUrlRequest(
      provider.imageUrl,
      headers: provider.headers,
      cacheKeyStrategy: provider.cacheKeyStrategy,
    );
    return 'network:${request.requestKey}|cacheKeyStrategy:${request.cacheKeyStrategy.name}|scale:${provider.scale}|avif:${provider.avifOverrideDurationMs}';
  }
  if (provider is NetworkImage) {
    final normalizedUrl = provider.url.trim();
    final headerEntries = provider.headers?.entries.toList()
      ?..sort((a, b) => a.key.compareTo(b.key));
    final headersHash = headerEntries == null
        ? 0
        : Object.hashAll(
            headerEntries.map((entry) => Object.hash(entry.key, entry.value)),
          );
    return 'network:$normalizedUrl|scale:${provider.scale}|headers:$headersHash';
  }
  if (provider is XNZFileImageProvider) {
    return 'file:${provider.file.path}|scale:${provider.scale}|avif:${provider.avifOverrideDurationMs}';
  }
  if (provider is FileImage) {
    return 'file:${provider.file.path}|scale:${provider.scale}';
  }
  if (provider is XNZAssetImageProvider) {
    return 'asset:${provider.assetName}|package:${provider.package}|bundle:${provider.bundle}|scale:${provider.scale}|avif:${provider.avifOverrideDurationMs}';
  }
  if (provider is AssetImage) {
    return 'asset:${provider.assetName}|package:${provider.package}';
  }
  if (provider is ExactAssetImage) {
    return 'asset:${provider.assetName}|package:${provider.package}|scale:${provider.scale}';
  }
  if (provider is XNZMemoryImageProvider) {
    // Fingerprint is cached by bytes identity in provider, preventing repeated
    // full-byte scans when the same in-memory image is rebuilt frequently.
    return 'memory:${provider.bytesFingerprint}|scale:${provider.scale}|avif:${provider.avifOverrideDurationMs}';
  }
  if (provider is MemoryImage) {
    return 'memory:${xnzStableBytesFingerprint(provider.bytes)}|scale:${provider.scale}';
  }
  return null;
}
