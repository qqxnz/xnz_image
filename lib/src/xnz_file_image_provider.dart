import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

import 'package:xnz_image/src/xnz_image_decode_utils.dart';
import 'package:xnz_image/src/xnz_proxy_image_stream_completer.dart';

class XNZFileImageProvider extends ImageProvider<XNZFileImageProvider> {
  static final Expando<ImageConfiguration> _lastImageConfigurations =
      Expando<ImageConfiguration>('xnz_file_image_configuration');

  const XNZFileImageProvider(
    this.file, {
    this.scale = 1.0,
    this.avifOverrideDurationMs = -1,
  });

  final File file;
  final double scale;
  final int? avifOverrideDurationMs;

  @override
  Future<XNZFileImageProvider> obtainKey(ImageConfiguration configuration) {
    XNZImageLogs.log('XNZFileImageProvider', 'obtainKey ${file.path}');
    _lastImageConfigurations[this] = configuration;
    return SynchronousFuture<XNZFileImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    XNZFileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    XNZImageLogs.log('XNZFileImageProvider', 'loadImage ${key.file.path}');
    final request = XNZImageRequest(
      sourceType: XNZImageSourceType.file,
      uri: key.file.uri,
      options: <String, Object?>{
        'scale': key.scale,
        'avifOverrideDurationMs': key.avifOverrideDurationMs,
      },
    );
    final resolved = XNZImageRegistry.instance.resolve(request);
    if (resolved?.provider != null) {
      XNZImageLogs.log('XNZFileImageProvider', 'loadImage-命中自定义支持');
      return XNZProxyImageStreamCompleter(
        provider: resolved!.provider!,
        configuration:
            _lastImageConfigurations[key] ?? ImageConfiguration.empty,
        debugLabel: 'XNZFileImageProvider(${key.file.path})',
        informationCollector: () sync* {
          yield ErrorDescription('XNZFileImageProvider Image provider: $this');
        },
      );
    }

    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: key.scale,
      informationCollector: () sync* {
        yield ErrorDescription('XNZFileImageProvider Image provider: $this');
      },
    );
  }

  Future<ui.Codec> _loadAsync(
    XNZFileImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    assert(key == this);
    XNZImageLogs.log(
        'XNZFileImageProvider', '_loadAsync-内置解码 ${key.file.path}');
    final bytes = await key.file.readAsBytes();
    return XNZImageDecodeUtils.decodeChecked(
      data: bytes,
      decode: decode,
      source: key.file.path,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XNZFileImageProvider &&
          runtimeType == other.runtimeType &&
          file.path == other.file.path &&
          scale == other.scale &&
          avifOverrideDurationMs == other.avifOverrideDurationMs;

  @override
  int get hashCode => Object.hash(file.path, scale, avifOverrideDurationMs);
}
