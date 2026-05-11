import 'package:flutter/widgets.dart';

import 'package:xnz_image/src/xnz_asset_image_provider.dart';
import 'package:xnz_image/src/xnz_file_image_provider.dart';
import 'package:xnz_image/src/xnz_memory_image_provider.dart';
import 'package:xnz_image/src/xnz_network_image_provider.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

int? xnzAnimatedAvifOverrideDuration(ImageProvider provider) {
  if (provider is XNZNetworkImageProvider) {
    return provider.avifOverrideDurationMs;
  }
  if (provider is XNZMemoryImageProvider) {
    return provider.avifOverrideDurationMs;
  }
  if (provider is XNZFileImageProvider) {
    return provider.avifOverrideDurationMs;
  }
  if (provider is XNZAssetImageProvider) {
    return provider.avifOverrideDurationMs;
  }
  return null;
}

double xnzAnimatedImageScale(ImageProvider provider) {
  if (provider is XNZNetworkImageProvider) {
    return provider.scale;
  }
  if (provider is XNZMemoryImageProvider) {
    return provider.scale;
  }
  if (provider is XNZFileImageProvider) {
    return provider.scale;
  }
  if (provider is XNZAssetImageProvider) {
    return provider.scale;
  }
  if (provider is NetworkImage) {
    return provider.scale;
  }
  if (provider is MemoryImage) {
    return provider.scale;
  }
  if (provider is FileImage) {
    return provider.scale;
  }
  if (provider is AssetImage) {
    return 1.0;
  }
  if (provider is ExactAssetImage) {
    return provider.scale;
  }
  return 1.0;
}

XNZImageSourceType? xnzAnimatedSourceTypeOf(ImageProvider provider) {
  if (provider is XNZNetworkImageProvider || provider is NetworkImage) {
    return XNZImageSourceType.network;
  }
  if (provider is XNZMemoryImageProvider || provider is MemoryImage) {
    return XNZImageSourceType.memory;
  }
  if (provider is XNZFileImageProvider || provider is FileImage) {
    return XNZImageSourceType.file;
  }
  if (provider is XNZAssetImageProvider ||
      provider is AssetImage ||
      provider is ExactAssetImage) {
    return XNZImageSourceType.asset;
  }
  return null;
}

Uri? xnzAnimatedUriOfProvider(ImageProvider provider) {
  if (provider is XNZNetworkImageProvider) {
    return Uri.tryParse(provider.imageUrl);
  }
  if (provider is NetworkImage) {
    return Uri.tryParse(provider.url);
  }
  if (provider is XNZFileImageProvider) {
    return provider.file.uri;
  }
  if (provider is FileImage) {
    return provider.file.uri;
  }
  if (provider is XNZAssetImageProvider) {
    final resolved = (provider.package == null || provider.package!.isEmpty)
        ? provider.assetName
        : 'packages/${provider.package}/${provider.assetName}';
    return Uri(path: resolved);
  }
  if (provider is AssetImage) {
    final resolved = (provider.package == null || provider.package!.isEmpty)
        ? provider.assetName
        : 'packages/${provider.package}/${provider.assetName}';
    return Uri(path: resolved);
  }
  if (provider is ExactAssetImage) {
    final resolved = (provider.package == null || provider.package!.isEmpty)
        ? provider.assetName
        : 'packages/${provider.package}/${provider.assetName}';
    return Uri(path: resolved);
  }
  return null;
}

Map<String, Object?> xnzAnimatedProviderOptions(ImageProvider provider) {
  if (provider is XNZAssetImageProvider) {
    return <String, Object?>{
      'assetName': provider.assetName,
      'bundle': provider.bundle,
      'package': provider.package,
    };
  }
  if (provider is AssetImage) {
    return <String, Object?>{
      'assetName': provider.assetName,
      'package': provider.package,
    };
  }
  if (provider is ExactAssetImage) {
    return <String, Object?>{
      'assetName': provider.assetName,
      'package': provider.package,
    };
  }
  return const <String, Object?>{};
}
