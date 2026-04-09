import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

class XNZProxyImageStreamCompleter extends ImageStreamCompleter {
  XNZProxyImageStreamCompleter({
    required ImageProvider provider,
    required ImageConfiguration configuration,
    String? debugLabel,
    InformationCollector? informationCollector,
  }) : _informationCollector = informationCollector {
    this.debugLabel = debugLabel;
    _stream = provider.resolve(configuration);
    _listener = ImageStreamListener(
      (imageInfo, _) {
        setImage(imageInfo);
      },
      onError: (Object error, StackTrace? stackTrace) {
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
  ImageStreamListener? _listener;

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
