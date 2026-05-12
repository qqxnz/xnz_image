import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

class XNZProxyImageStreamCompleter extends ImageStreamCompleter {
  XNZProxyImageStreamCompleter({
    required ImageProvider provider,
    required ImageConfiguration configuration,
    String? debugLabel,
    InformationCollector? informationCollector,
  })  : _informationCollector = informationCollector,
        _debugLabel = debugLabel {
    this.debugLabel = debugLabel;
    XNZImageLogs.event('XNZProxyImageStreamCompleter', 'display_subscribe',
        fields: {
          'debugLabel': debugLabel ?? '',
          'provider': provider.runtimeType.toString(),
        });
    _stream = provider.resolve(configuration);
    _listener = ImageStreamListener(
      (imageInfo, _) {
        if (!_firstFrameEmitted) {
          _firstFrameEmitted = true;
          XNZImageLogs.event(
            'XNZProxyImageStreamCompleter',
            'display_first_frame',
            fields: {
              'debugLabel': _debugLabel ?? '',
              'width': imageInfo.image.width,
              'height': imageInfo.image.height,
            },
          );
        }
        setImage(imageInfo);
      },
      onError: (Object error, StackTrace? stackTrace) {
        XNZImageLogs.event(
          'XNZProxyImageStreamCompleter',
          'display_failed',
          fields: {
            'debugLabel': _debugLabel ?? '',
            'error': error,
          },
        );
        reportError(
          context: ErrorDescription('resolving delegated image stream'),
          exception: error,
          stack: stackTrace,
          informationCollector: _informationCollector,
          silent: true,
        );
      },
    );
    _stream.addListener(_listener!);
  }

  late final ImageStream _stream;
  final InformationCollector? _informationCollector;
  final String? _debugLabel;
  ImageStreamListener? _listener;
  bool _firstFrameEmitted = false;

  @override
  void removeListener(ImageStreamListener listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _disposeInternal();
    }
  }

  void _disposeInternal() {
    final listener = _listener;
    if (listener == null) {
      return;
    }
    _stream.removeListener(listener);
    _listener = null;
  }
}
