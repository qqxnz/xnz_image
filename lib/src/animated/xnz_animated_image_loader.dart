import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:xnz_image/src/xnz_asset_image_provider.dart';
import 'package:xnz_image/src/xnz_file_image_provider.dart';
import 'package:xnz_image/src/xnz_memory_image_provider.dart';
import 'package:xnz_image/src/xnz_network_bytes_loader.dart';
import 'package:xnz_image/src/xnz_network_image_provider.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

/// Loads raw bytes for supported [ImageProvider] implementations.
Future<Uint8List> xnzLoadBytesFromProvider(ImageProvider provider) async {
  if (provider is MemoryImage) {
    return provider.bytes;
  }
  if (provider is XNZMemoryImageProvider) {
    return provider.bytes;
  }
  if (provider is FileImage) {
    return provider.file.readAsBytes();
  }
  if (provider is XNZFileImageProvider) {
    return provider.file.readAsBytes();
  }
  if (provider is XNZNetworkImageProvider) {
    final request = XNZUrlRequest(
      provider.imageUrl,
      headers: provider.headers,
      cacheKeyStrategy: provider.cacheKeyStrategy,
    );
    final cached = await XNZCacheManager().getCache(request);
    if (cached != null) {
      return cached;
    }
    return xnzLoadNetworkBytes(
      Uri.parse(provider.imageUrl),
      headers: provider.headers,
      cacheKeyStrategy: provider.cacheKeyStrategy,
    );
  }
  if (provider is NetworkImage) {
    return xnzLoadNetworkBytes(
      Uri.parse(provider.url),
      headers: provider.headers,
      cacheKeyStrategy: provider.headers != null && provider.headers!.isNotEmpty
          ? XNZCacheKeyStrategy.urlAndHeaders
          : XNZCacheKeyStrategy.urlOnly,
    );
  }

  if (provider is AssetImage) {
    final key = await provider.obtainKey(ImageConfiguration.empty);
    final data = await key.bundle.load(key.name);
    return data.buffer.asUint8List();
  }
  if (provider is ExactAssetImage) {
    final key = await provider.obtainKey(ImageConfiguration.empty);
    final data = await key.bundle.load(key.name);
    return data.buffer.asUint8List();
  }
  if (provider is XNZAssetImageProvider) {
    final assetName = (provider.package == null || provider.package!.isEmpty)
        ? provider.assetName
        : 'packages/${provider.package}/${provider.assetName}';
    final data = await (provider.bundle ?? rootBundle).load(assetName);
    return data.buffer.asUint8List();
  }

  throw UnsupportedError(
    'Unsupported ImageProvider type: ${provider.runtimeType}. '
    'Use Memory/File/Network/Asset providers or pass a custom decoder.',
  );
}
