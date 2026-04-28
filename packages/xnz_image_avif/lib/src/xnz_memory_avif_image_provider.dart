import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_avif_platform_interface/flutter_avif_platform_interface.dart'
    as avif_platform;

/// 轻量 AVIF 内存图像提供器实现。
///
/// 该文件参考 `flutter_avif` 的核心解码/帧调度逻辑，仅保留
/// `xnz_network_image` 需要的内存字节解码能力，避免直接依赖 `flutter_avif` 组件层。
T? _ambiguate<T>(T? value) => value;

enum AvifFileType { avif, avis, unknown }

/// 通过文件头识别字节流是否为 avif/avis。
bool isAvifBytes(Uint8List bytes) {
  if (bytes.length < 16) {
    return false;
  }
  return _getAvifFileType(bytes.sublist(0, 16)) != AvifFileType.unknown;
}

/// 将内存字节流转换为可播放的 AVIF codec。
///
/// 普通 AVIF（单帧）走 [SingleFrameAvifCodec]，
/// 动图 AVIF（多帧）走 [MultiFrameAvifCodec]。
Future<AvifCodec> loadMemoryAvifCodec(
  Uint8List bytes, {
  required int codecKey,
  int? avifOverrideDurationMs = -1,
}) async {
  const int _avifHeaderLength = 16;
  final bytesUint8List = bytes.buffer.asUint8List(0, bytes.length);
  if (bytesUint8List.length < _avifHeaderLength) {
    throw const FormatException(
      'Invalid AVIF bytes: empty or truncated data.',
    );
  }
  final fType = _getAvifFileType(bytesUint8List.sublist(0, _avifHeaderLength));
  if (fType == AvifFileType.unknown) {
    throw StateError('Loaded file is not an avif file.');
  }

  final codec = fType == AvifFileType.avif
      ? SingleFrameAvifCodec(bytes: bytesUint8List)
      : MultiFrameAvifCodec(
          key: codecKey,
          avifBytes: bytesUint8List,
          avifOverrideDurationMs: avifOverrideDurationMs,
        );
  await codec.ready();

  return codec;
}

class XNZMemoryAvifImage extends ImageProvider<XNZMemoryAvifImage> {
  const XNZMemoryAvifImage(
    this.bytes, {
    this.scale = 1.0,
    this.avifOverrideDurationMs = -1,
  });

  final Uint8List bytes;
  final double scale;
  final int? avifOverrideDurationMs;

  @override
  Future<XNZMemoryAvifImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<XNZMemoryAvifImage>(this);
  }

  @override
  ImageStreamCompleter loadImage(
      XNZMemoryAvifImage key, ImageDecoderCallback decode) {
    // 使用自定义 completer 处理 AVIF 多帧调度。
    return AvifImageStreamCompleter(
      key: key,
      codec: _loadAsync(key),
      scale: key.scale,
      debugLabel: 'XNZMemoryAvifImage(${describeIdentity(key.bytes)})',
    );
  }

  Future<AvifCodec> _loadAsync(XNZMemoryAvifImage key) async {
    assert(key == this);
    if (kIsWeb) {
      throw UnsupportedError(
        'XNZMemoryAvifImage does not support the web platform.',
      );
    }
    return loadMemoryAvifCodec(
      bytes,
      codecKey: hashCode,
      avifOverrideDurationMs: avifOverrideDurationMs,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is XNZMemoryAvifImage &&
        other.bytes == bytes &&
        other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(bytes.hashCode, scale);
}

abstract class AvifCodec {
  int get frameCount;
  int get durationMs;

  Future<void> ready();
  Future<AvifFrameInfo> getNextFrame();
  void dispose();
}

class MultiFrameAvifCodec implements AvifCodec {
  final String _key;
  late Completer<void> _ready;

  int _frameCount = 1;
  @override
  int get frameCount => _frameCount;

  int _durationMs = -1;
  @override
  int get durationMs => _durationMs;

  MultiFrameAvifCodec({
    required int key,
    required Uint8List avifBytes,
    int? avifOverrideDurationMs = -1,
  }) : _key = key.toString() {
    _ready = Completer<void>();
    try {
      final avifFfi = avif_platform.FlutterAvifPlatform.api;
      // 初始化原生 decoder，并拿到帧数和时长信息。
      avifFfi.initMemoryDecoder(key: _key, avifBytes: avifBytes).then((info) {
        _frameCount = info.imageCount;
        _durationMs = avifOverrideDurationMs ?? (info.duration * 1000).round();
        _ready.complete();
      });
    } catch (_) {
      _ready.complete();
    }
  }

  @override
  Future<void> ready() async {
    if (_ready.isCompleted) {
      return;
    }
    await _ready.future;
  }

  @override
  Future<AvifFrameInfo> getNextFrame() async {
    final completer = Completer<AvifFrameInfo>.sync();
    final String? error =
        _getNextFrame((ui.Image? image, int durationMilliseconds) {
      if (image == null) {
        completer.completeError(
          Exception(
            'Codec failed to produce an image, possibly due to invalid image data.',
          ),
        );
      } else {
        completer.complete(
          AvifFrameInfo(
            image: image,
            duration: Duration(milliseconds: durationMilliseconds),
          ),
        );
      }
    });
    if (error != null) {
      throw Exception(error);
    }
    return completer.future;
  }

  String? _getNextFrame(void Function(ui.Image?, int) callback) {
    try {
      final avifFfi = avif_platform.FlutterAvifPlatform.api;
      avifFfi.getNextFrame(key: _key).then((frame) {
        // 原生返回 RGBA 数据，转换成 `ui.Image` 后交给上层。
        ui.decodeImageFromPixels(
          Uint8List.fromList(frame.data),
          frame.width,
          frame.height,
          ui.PixelFormat.rgba8888,
          (image) {
            callback(image, (frame.duration * 1000).round());
          },
        );
      });
      return null;
    } catch (e) {
      callback(null, 0);
      return e.toString();
    }
  }

  @override
  void dispose() {
    final avifFfi = avif_platform.FlutterAvifPlatform.api;
    avifFfi.disposeDecoder(key: _key);
  }
}

class SingleFrameAvifCodec implements AvifCodec {
  @override
  int get frameCount => 1;

  @override
  int get durationMs => -1;

  final Uint8List _bytes;

  SingleFrameAvifCodec({
    required Uint8List bytes,
  }) : _bytes = bytes;

  @override
  Future<void> ready() async {}

  @override
  Future<AvifFrameInfo> getNextFrame() async {
    final completer = Completer<AvifFrameInfo>.sync();
    final String? error =
        _getNextFrame((ui.Image? image, int durationMilliseconds) {
      if (image == null) {
        completer.completeError(
          Exception(
            'Codec failed to produce an image, possibly due to invalid image data.',
          ),
        );
      } else {
        completer.complete(
          AvifFrameInfo(
            image: image,
            duration: Duration(milliseconds: durationMilliseconds),
          ),
        );
      }
    });
    if (error != null) {
      throw Exception(error);
    }
    return completer.future;
  }

  String? _getNextFrame(void Function(ui.Image?, int) callback) {
    try {
      final avifFfi = avif_platform.FlutterAvifPlatform.api;
      avifFfi.decodeSingleFrameImage(avifBytes: _bytes).then((frame) {
        // 单帧仍走统一的 RGBA -> `ui.Image` 转换链路。
        ui.decodeImageFromPixels(
          Uint8List.fromList(frame.data),
          frame.width,
          frame.height,
          ui.PixelFormat.rgba8888,
          (image) {
            callback(image, (frame.duration * 1000).round());
          },
        );
      });
      return null;
    } catch (e) {
      callback(null, 0);
      return e.toString();
    }
  }

  @override
  void dispose() {}
}

class AvifFrameInfo {
  final Duration duration;
  final ui.Image image;

  AvifFrameInfo({required this.duration, required this.image});
}

class AvifImageStreamCompleter extends ImageStreamCompleter {
  AvifImageStreamCompleter({
    required ImageProvider key,
    required Future<AvifCodec> codec,
    required double scale,
    String? debugLabel,
    Stream<ImageChunkEvent>? chunkEvents,
    InformationCollector? informationCollector,
  })  : _informationCollector = informationCollector,
        _scale = scale,
        _key = key {
    this.debugLabel = debugLabel;
    codec.then<void>(_handleCodecReady,
        onError: (Object error, StackTrace stack) {
      reportError(
        context: ErrorDescription('resolving an image codec'),
        exception: error,
        stack: stack,
        informationCollector: informationCollector,
        silent: true,
      );
    });
    if (chunkEvents != null) {
      _chunkSubscription = chunkEvents.listen(
        reportImageChunkEvent,
        onError: (Object error, StackTrace stack) {
          reportError(
            context: ErrorDescription('loading an image'),
            exception: error,
            stack: stack,
            informationCollector: informationCollector,
            silent: true,
          );
        },
      );
    }
  }

  StreamSubscription<ImageChunkEvent>? _chunkSubscription;
  AvifCodec? _codec;
  final double _scale;
  final InformationCollector? _informationCollector;
  AvifFrameInfo? _nextFrame;
  ImageInfo? _currentFrame;
  late Duration _shownTimestamp;
  Duration? _frameDuration;
  int _duration = 0;
  Timer? _timer;
  final ImageProvider _key;

  bool _frameCallbackScheduled = false;

  void _handleCodecReady(AvifCodec codec) {
    _codec = codec;
    assert(_codec != null);

    if (hasListeners) {
      // 首次有监听时，启动首帧解码。
      _decodeNextFrameAndSchedule();
    }
  }

  void _handleAppFrame(Duration timestamp) {
    _frameCallbackScheduled = false;
    if (!hasListeners) return;
    assert(_nextFrame != null);
    if (_isFirstFrame() || _hasFrameDurationPassed(timestamp)) {
      _emitFrame(ImageInfo(
        image: _nextFrame!.image.clone(),
        scale: _scale,
        debugLabel: debugLabel,
      ));
      _shownTimestamp = timestamp;
      _frameDuration = _nextFrame!.duration;
      _nextFrame!.image.dispose();
      _nextFrame = null;
      if (_codec!.durationMs == -1 || _codec!.durationMs > _duration) {
        // 还在可播放时长内，继续请求下一帧。
        _decodeNextFrameAndSchedule();
      }
      return;
    }
    final delay = _frameDuration! - (timestamp - _shownTimestamp);
    _timer = Timer(delay * timeDilation, _scheduleAppFrame);
  }

  bool _isFirstFrame() {
    return _frameDuration == null;
  }

  bool _hasFrameDurationPassed(Duration timestamp) {
    return timestamp - _shownTimestamp >= _frameDuration!;
  }

  Future<void> _decodeNextFrameAndSchedule() async {
    _nextFrame?.image.dispose();
    _nextFrame = null;
    try {
      _nextFrame = await _codec!.getNextFrame();
    } catch (exception, stack) {
      reportError(
        context: ErrorDescription('resolving an image frame'),
        exception: exception,
        stack: stack,
        informationCollector: _informationCollector,
        silent: true,
      );
      return;
    }
    if (_codec!.frameCount == 1) {
      if (!hasListeners) {
        return;
      }
      // 单帧图只发一次，不再进行帧调度。
      _emitFrame(ImageInfo(
        image: _nextFrame!.image.clone(),
        scale: _scale,
        debugLabel: debugLabel,
      ));
      _nextFrame!.image.dispose();
      _nextFrame = null;
      return;
    }
    _scheduleAppFrame();
  }

  void _scheduleAppFrame() {
    if (_frameCallbackScheduled) {
      return;
    }
    _frameCallbackScheduled = true;
    _ambiguate(SchedulerBinding.instance)!
        .scheduleFrameCallback(_handleAppFrame);
  }

  void _emitFrame(ImageInfo imageInfo) {
    setImage(imageInfo);
    _duration += _nextFrame?.duration.inMilliseconds ?? 0;
  }

  @override
  void addListener(ImageStreamListener listener) {
    if (!hasListeners &&
        _codec != null &&
        (_currentFrame == null || _codec!.frameCount > 1)) {
      _decodeNextFrameAndSchedule();
    }
    super.addListener(listener);
  }

  @override
  void removeListener(ImageStreamListener listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }

  bool getHasListeners() => hasListeners;

  @override
  void setImage(ImageInfo image) {
    _currentFrame = image;
    super.setImage(image);
  }

  void dispose() {
    _chunkSubscription?.onData(null);
    _chunkSubscription?.cancel();
    _chunkSubscription = null;
  }

  @override
  ImageStreamCompleterHandle keepAlive() {
    // 自定义 handle 负责在合适时机释放底层 decoder。
    final handle = super.keepAlive();
    return AvifImageStreamCompleterHandle(handle, this);
  }
}

class AvifImageStreamCompleterHandle implements ImageStreamCompleterHandle {
  final ImageStreamCompleterHandle _handle;
  final AvifImageStreamCompleter _completer;

  AvifImageStreamCompleterHandle(this._handle, this._completer);

  @override
  void dispose() {
    _handle.dispose();
    if (!_completer.getHasListeners() &&
        !PaintingBinding.instance.imageCache.containsKey(_completer._key)) {
      // 避免 decoder 资源泄漏。
      _completer._codec?.dispose();
    }
  }
}

AvifFileType _getAvifFileType(Uint8List bytes) {
  if (_isSubset(bytes, [102, 116, 121, 112, 97, 118, 105, 102])) {
    return AvifFileType.avif;
  }

  if (_isSubset(bytes, [102, 116, 121, 112, 97, 118, 105, 115])) {
    return AvifFileType.avis;
  }

  return AvifFileType.unknown;
}

bool _isSubset(List<int> arr1, List<int> arr2) {
  for (int i = 0; i < arr1.length - arr2.length + 1; i++) {
    int j = 0;
    for (; j < arr2.length; j++) {
      if (arr1[i + j] != arr2[j]) break;
    }
    if (j == arr2.length) return true;
  }
  return false;
}
