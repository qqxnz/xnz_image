import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:xnz_image_core/xnz_image_core.dart';

import 'xnz_asset_image_provider.dart';
import 'xnz_file_image_provider.dart';
import 'xnz_memory_image_provider.dart';
import 'xnz_network_image_provider.dart';

typedef XNZAnimatedImageDecoder = Future<Object?> Function(
  XNZAnimatedImageDecodeRequest request,
);

@immutable
class XNZAnimatedImageDecodeRequest {
  const XNZAnimatedImageDecodeRequest({
    required this.image,
    required this.bytes,
    required this.scale,
    this.avifOverrideDurationMs,
  });

  final ImageProvider image;
  final Uint8List bytes;
  final double scale;
  final int? avifOverrideDurationMs;
}

@immutable
class XNZAnimatedImageFrame {
  const XNZAnimatedImageFrame({
    required this.image,
    required this.duration,
    this.scale = 1.0,
  });

  final ui.Image image;
  final Duration duration;
  final double scale;
}

@immutable
class XNZAnimatedImageData {
  const XNZAnimatedImageData({
    required this.frames,
    required this.duration,
  });

  final List<XNZAnimatedImageFrame> frames;
  final Duration duration;
}

@immutable
class XNZAnimatedImageCache {
  final Map<String, XNZAnimatedImageData> caches =
      <String, XNZAnimatedImageData>{};

  void clear() {
    for (final cached in caches.values) {
      for (final frame in cached.frames) {
        frame.image.dispose();
      }
    }
    caches.clear();
  }

  bool evict(Object key) {
    final removed = caches.remove(key);
    if (removed == null) {
      return false;
    }
    for (final frame in removed.frames) {
      frame.image.dispose();
    }
    return true;
  }
}

class XNZAnimatedImageController extends ChangeNotifier {
  VoidCallback? _playCallback;
  VoidCallback? _pauseCallback;
  VoidCallback? _resumeCallback;
  VoidCallback? _replayCallback;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  int _frameIndex = 0;
  int _completedLoops = 0;
  bool _isPlaying = false;
  bool _isCompleted = false;

  Duration get position => _position;
  Duration get duration => _duration;
  int get frameIndex => _frameIndex;
  int get completedLoops => _completedLoops;
  bool get isPlaying => _isPlaying;
  bool get isCompleted => _isCompleted;

  double get progress {
    final totalMs = _duration.inMilliseconds;
    if (totalMs <= 0) {
      return 0;
    }
    return (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  void play() => _playCallback?.call();

  void pause() => _pauseCallback?.call();

  void resume() => _resumeCallback?.call();

  void replay() => _replayCallback?.call();

  void bind({
    required VoidCallback onPlay,
    required VoidCallback onPause,
    required VoidCallback onResume,
    required VoidCallback onReplay,
  }) {
    _playCallback = onPlay;
    _pauseCallback = onPause;
    _resumeCallback = onResume;
    _replayCallback = onReplay;
  }

  void unbind() {
    _playCallback = null;
    _pauseCallback = null;
    _resumeCallback = null;
    _replayCallback = null;
  }

  void sync({
    required Duration position,
    required Duration duration,
    required int frameIndex,
    required int completedLoops,
    required bool isPlaying,
    required bool isCompleted,
  }) {
    final changed = _position != position ||
        _duration != duration ||
        _frameIndex != frameIndex ||
        _completedLoops != completedLoops ||
        _isPlaying != isPlaying ||
        _isCompleted != isCompleted;
    _position = position;
    _duration = duration;
    _frameIndex = frameIndex;
    _completedLoops = completedLoops;
    _isPlaying = isPlaying;
    _isCompleted = isCompleted;
    if (changed) {
      notifyListeners();
    }
  }
}

@immutable
class XNZAnimatedImage extends StatefulWidget {
  const XNZAnimatedImage({
    super.key,
    required this.image,
    this.controller,
    this.loadingBuilder,
    this.errorBuilder,
    this.onLoaded,
    this.onCompleted,
    this.decoder,
    this.autoPlay = true,
    this.loop = true,
    this.useCache = true,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.width,
    this.height,
    this.color,
    this.colorBlendMode,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = ImageRepeat.noRepeat,
    this.centerSlice,
    this.matchTextDirection = false,
  });

  static XNZAnimatedImageCache cache = XNZAnimatedImageCache();

  final ImageProvider image;
  final XNZAnimatedImageController? controller;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  )? errorBuilder;
  final void Function(Duration duration, int fps, int frameCount)? onLoaded;
  final void Function(int completedLoops)? onCompleted;
  final XNZAnimatedImageDecoder? decoder;
  final bool autoPlay;
  final bool loop;
  final bool useCache;
  final double? width;
  final double? height;
  final Color? color;
  final BlendMode? colorBlendMode;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final ImageRepeat repeat;
  final Rect? centerSlice;
  final bool matchTextDirection;
  final String? semanticLabel;
  final bool excludeFromSemantics;

  @override
  State<XNZAnimatedImage> createState() => _XNZAnimatedImageState();
}

class _XNZAnimatedImageState extends State<XNZAnimatedImage>
    with SingleTickerProviderStateMixin {
  late final XNZAnimatedImageController _innerController;
  late XNZAnimatedImageController _activeController;
  late final Ticker _ticker;

  List<XNZAnimatedImageFrame> _frames = const <XNZAnimatedImageFrame>[];
  List<int> _frameEndMs = const <int>[];
  Duration _duration = Duration.zero;

  int _frameIndex = 0;
  int _completedLoops = 0;
  Duration _position = Duration.zero;
  int _sessionStartPositionMs = 0;
  int _sessionStartLoopCount = 0;
  bool _isPlaying = false;
  bool _isCompleted = false;
  int _loadToken = 0;
  Object? _loadError;
  StackTrace? _loadErrorStackTrace;

  XNZAnimatedImageFrame? get _frame =>
      _frames.length > _frameIndex ? _frames[_frameIndex] : null;

  @override
  void initState() {
    super.initState();
    _innerController = XNZAnimatedImageController();
    _activeController = widget.controller ?? _innerController;
    _ticker = createTicker(_onTick);
    _bindController(_activeController);
    unawaited(_loadFrames());
  }

  @override
  void didUpdateWidget(XNZAnimatedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _activeController.unbind();
      _activeController = widget.controller ?? _innerController;
      _bindController(_activeController);
      _syncControllerState();
    }

    if (widget.image != oldWidget.image ||
        widget.decoder != oldWidget.decoder ||
        widget.useCache != oldWidget.useCache) {
      _resetPlayback();
      unawaited(_loadFrames());
    }
  }

  @override
  void dispose() {
    _activeController.unbind();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = RawImage(
      image: _frame?.image,
      width: widget.width,
      height: widget.height,
      scale: _frame?.scale ?? 1.0,
      color: widget.color,
      colorBlendMode: widget.colorBlendMode,
      fit: widget.fit,
      alignment: widget.alignment,
      repeat: widget.repeat,
      centerSlice: widget.centerSlice,
      matchTextDirection: widget.matchTextDirection,
    );

    if (_frame == null && _loadError != null && widget.errorBuilder != null) {
      return widget.errorBuilder!(context, _loadError!, _loadErrorStackTrace);
    }
    if (widget.loadingBuilder != null && _frame == null) {
      return widget.loadingBuilder!(context);
    }
    if (widget.excludeFromSemantics) {
      return image;
    }
    return Semantics(
      container: widget.semanticLabel != null,
      image: true,
      label: widget.semanticLabel ?? '',
      child: image,
    );
  }

  void _bindController(XNZAnimatedImageController controller) {
    controller.bind(
      onPlay: _play,
      onPause: _pause,
      onResume: _resume,
      onReplay: _replay,
    );
  }

  void _resetPlayback() {
    _ticker.stop();
    _frameIndex = 0;
    _completedLoops = 0;
    _position = Duration.zero;
    _sessionStartPositionMs = 0;
    _sessionStartLoopCount = 0;
    _isPlaying = false;
    _isCompleted = false;
    _syncControllerState();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadFrames() async {
    if (!mounted) {
      return;
    }
    final loadToken = ++_loadToken;
    _loadError = null;
    _loadErrorStackTrace = null;
    try {
      final key = _cacheKey(widget.image);
      XNZAnimatedImageData? decoded;
      if (widget.useCache && key != null) {
        decoded = XNZAnimatedImage.cache.caches[key];
      }
      decoded ??= await _decodeImage(widget.image);

      if (!mounted || loadToken != _loadToken) {
        return;
      }

      if (widget.useCache && key != null) {
        XNZAnimatedImage.cache.caches.putIfAbsent(key, () => decoded!);
      }

      final frameEndMs = <int>[];
      var totalMs = 0;
      for (final frame in decoded.frames) {
        final frameMs = frame.duration.inMilliseconds;
        totalMs += frameMs <= 0 ? 1 : frameMs;
        frameEndMs.add(totalMs);
      }
      final isStatic = decoded.frames.length <= 1;

      setState(() {
        _frames = decoded!.frames;
        _duration = isStatic
            ? Duration.zero
            : decoded.duration.inMilliseconds <= 0
                ? Duration(milliseconds: totalMs)
                : decoded.duration;
        _frameEndMs = List<int>.unmodifiable(frameEndMs);
        _frameIndex = 0;
        _position = Duration.zero;
        _sessionStartPositionMs = 0;
        _sessionStartLoopCount = 0;
        _isCompleted = false;
        _completedLoops = 0;
      });

      final durationMs = _duration.inMilliseconds;
      final fps =
          durationMs <= 0 ? 0 : ((_frames.length * 1000) / durationMs).round();
      final onLoaded = widget.onLoaded;
      if (onLoaded != null) {
        scheduleMicrotask(() {
          if (!mounted || loadToken != _loadToken) {
            return;
          }
          onLoaded(_duration, fps, _frames.length);
        });
      }
      _syncControllerState();

      if (widget.autoPlay) {
        _play();
      }
    } catch (e, st) {
      if (!mounted || loadToken != _loadToken) {
        return;
      }
      setState(() {
        _loadError = e;
        _loadErrorStackTrace = st;
      });
    }
  }

  Future<XNZAnimatedImageData> _decodeImage(ImageProvider provider) async {
    final bytes = await _loadBytes(provider);
    final request = XNZAnimatedImageDecodeRequest(
      image: provider,
      bytes: bytes,
      scale: _imageScale(provider),
      avifOverrideDurationMs: _avifOverrideDuration(provider),
    );

    final supportDecoder = _resolveSupportAnimatedDecoder(
      provider: provider,
      bytes: bytes,
      scale: request.scale,
      avifOverrideDurationMs: request.avifOverrideDurationMs,
    );
    final effectiveDecoder = widget.decoder ?? supportDecoder;
    final customDecodedRaw = await effectiveDecoder?.call(request);
    final customDecoded = _coerceDecodedData(customDecodedRaw);
    if (customDecoded != null) {
      return customDecoded;
    }
    return _defaultDecode(request);
  }

  static XNZAnimatedImageDecoder? _resolveSupportAnimatedDecoder({
    required ImageProvider provider,
    required Uint8List bytes,
    required double scale,
    required int? avifOverrideDurationMs,
  }) {
    final sourceType = _sourceTypeOf(provider);
    if (sourceType == null) {
      return null;
    }
    final request = XNZImageRequest(
      sourceType: sourceType,
      uri: _uriOfProvider(provider),
      bytes: sourceType == XNZImageSourceType.memory ? bytes : null,
      options: <String, Object?>{
        ..._providerOptions(provider),
        'scale': scale,
        'avifOverrideDurationMs': avifOverrideDurationMs,
      },
    );

    final resolved = XNZImageRegistry.instance.resolve(request);
    final meta = resolved?.meta;
    if (meta is Map<Object?, Object?>) {
      final decoder = meta['animatedDecoder'];
      if (decoder is XNZAnimatedImageDecoder) {
        return decoder;
      }
      if (decoder is Function) {
        return (decodeRequest) async => await decoder(decodeRequest);
      }
    }
    return null;
  }

  static XNZAnimatedImageData? _coerceDecodedData(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is XNZAnimatedImageData) {
      return value;
    }
    if (value is! Map<Object?, Object?>) {
      return null;
    }

    final rawFrames = value['frames'];
    if (rawFrames is! List) {
      return null;
    }

    final frames = <XNZAnimatedImageFrame>[];
    final isSingleFrame = rawFrames.length <= 1;
    for (final rawFrame in rawFrames) {
      if (rawFrame is! Map<Object?, Object?>) {
        return null;
      }
      final image = rawFrame['image'];
      final duration = rawFrame['duration'];
      final scale = rawFrame['scale'];
      if (image is! ui.Image || duration is! Duration) {
        return null;
      }
      frames.add(
        XNZAnimatedImageFrame(
          image: image,
          duration: isSingleFrame
              ? duration
              : duration.inMilliseconds <= 0
                  ? const Duration(milliseconds: 1)
                  : duration,
          scale: scale is num ? scale.toDouble() : 1.0,
        ),
      );
    }

    final rawDuration = value['duration'];
    final totalDuration =
        rawDuration is Duration ? rawDuration : _sumDuration(frames);
    return XNZAnimatedImageData(
      frames: frames,
      duration: totalDuration.inMilliseconds <= 0
          ? _sumDuration(frames)
          : totalDuration,
    );
  }

  static Duration _sumDuration(List<XNZAnimatedImageFrame> frames) {
    if (frames.length <= 1) {
      return Duration.zero;
    }
    var duration = Duration.zero;
    for (final frame in frames) {
      duration += frame.duration.inMilliseconds <= 0
          ? const Duration(milliseconds: 1)
          : frame.duration;
    }
    return duration;
  }

  static Future<XNZAnimatedImageData> _defaultDecode(
    XNZAnimatedImageDecodeRequest request,
  ) async {
    final codec = await ui.instantiateImageCodec(
      request.bytes,
      targetWidth: null,
      targetHeight: null,
    );

    final frames = <XNZAnimatedImageFrame>[];
    var totalDuration = Duration.zero;
    final isSingleFrame = codec.frameCount <= 1;
    try {
      for (var i = 0; i < codec.frameCount; i++) {
        final frame = await codec.getNextFrame();
        final frameDuration = isSingleFrame
            ? frame.duration
            : frame.duration.inMilliseconds <= 0
                ? const Duration(milliseconds: 1)
                : frame.duration;
        frames.add(
          XNZAnimatedImageFrame(
            image: frame.image,
            duration: frameDuration,
            scale: request.scale,
          ),
        );
        totalDuration += frameDuration;
      }
    } finally {
      codec.dispose();
    }
    return XNZAnimatedImageData(frames: frames, duration: totalDuration);
  }

  void _play() {
    if (_isPlaying) {
      return;
    }
    if (_frames.isEmpty) {
      return;
    }
    _isCompleted = false;
    if (_duration.inMilliseconds <= 0) {
      _isPlaying = false;
      _frameIndex = 0;
      _position = Duration.zero;
      _sessionStartPositionMs = 0;
      _sessionStartLoopCount = _completedLoops;
      _syncControllerState();
      if (mounted) {
        setState(() {});
      }
      return;
    }
    _sessionStartPositionMs = _position.inMilliseconds;
    _sessionStartLoopCount = _completedLoops;
    _ticker.start();
    _isPlaying = true;
    _syncControllerState();
  }

  void _pause() {
    if (!_isPlaying) {
      return;
    }
    _ticker.stop();
    _isPlaying = false;
    _syncControllerState();
  }

  void _resume() {
    if (_isPlaying || _frames.isEmpty || _isCompleted) {
      return;
    }
    _play();
  }

  void _replay() {
    if (_frames.isEmpty) {
      return;
    }
    _ticker.stop();
    _position = Duration.zero;
    _sessionStartPositionMs = 0;
    _sessionStartLoopCount = 0;
    _frameIndex = 0;
    _completedLoops = 0;
    _isCompleted = false;
    if (mounted) {
      setState(() {});
    }
    _play();
  }

  void _onTick(Duration elapsedSinceStart) {
    if (_frames.isEmpty) {
      return;
    }
    final totalMs = _duration.inMilliseconds;
    if (totalMs <= 0) {
      return;
    }

    final totalElapsedMs =
        _sessionStartPositionMs + elapsedSinceStart.inMilliseconds;
    final loopsDelta = totalElapsedMs ~/ totalMs;
    final loopPositionMs = totalElapsedMs % totalMs;
    final nextCompletedLoops = _sessionStartLoopCount + loopsDelta;

    if (nextCompletedLoops > _completedLoops) {
      for (var loop = _completedLoops + 1; loop <= nextCompletedLoops; loop++) {
        widget.onCompleted?.call(loop);
      }
    }

    if (!widget.loop && nextCompletedLoops > 0) {
      _ticker.stop();
      _isPlaying = false;
      _isCompleted = true;
      _completedLoops = 1;
      _position = _duration;
      _frameIndex = _frames.length - 1;
      _syncControllerState();
      if (mounted) {
        setState(() {});
      }
      return;
    }

    _completedLoops = nextCompletedLoops;
    final nextPosition = Duration(milliseconds: loopPositionMs);
    final nextIndex = _frameIndexFor(loopPositionMs);
    final changed = nextPosition != _position || nextIndex != _frameIndex;

    _position = nextPosition;
    _frameIndex = nextIndex;
    _isCompleted = false;

    _syncControllerState();
    if (changed && mounted) {
      setState(() {});
    }
  }

  int _frameIndexFor(int ms) {
    if (_frameEndMs.isEmpty) {
      return 0;
    }
    for (var i = 0; i < _frameEndMs.length; i++) {
      if (ms < _frameEndMs[i]) {
        return i;
      }
    }
    return _frameEndMs.length - 1;
  }

  void _syncControllerState() {
    _activeController.sync(
      position: _position,
      duration: _duration,
      frameIndex: _frameIndex,
      completedLoops: _completedLoops,
      isPlaying: _isPlaying,
      isCompleted: _isCompleted,
    );
  }

  static Future<Uint8List> _loadBytes(ImageProvider provider) async {
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
      final cached = await XNZCacheManager().getCache(provider.imageUrl);
      if (cached != null) {
        return cached;
      }
      return _loadNetworkBytes(Uri.parse(provider.imageUrl));
    }
    if (provider is NetworkImage) {
      return _loadNetworkBytes(
        Uri.parse(provider.url),
        headers: provider.headers,
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

  static Future<Uint8List> _loadNetworkBytes(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(uri);
      headers?.forEach(request.headers.add);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Request failed, statusCode: ${response.statusCode}',
          uri: uri,
        );
      }
      final bytes = await consolidateHttpClientResponseBytes(response);
      return Uint8List.fromList(bytes);
    } finally {
      httpClient.close(force: true);
    }
  }

  static String? _cacheKey(ImageProvider provider) {
    if (provider is XNZNetworkImageProvider) {
      return 'network:${provider.imageUrl}|scale:${provider.scale}|avif:${provider.avifOverrideDurationMs}';
    }
    if (provider is NetworkImage) {
      return 'network:${provider.url}|scale:${provider.scale}';
    }
    if (provider is XNZFileImageProvider) {
      return 'file:${provider.file.path}|scale:${provider.scale}|avif:${provider.avifOverrideDurationMs}';
    }
    if (provider is FileImage) {
      return 'file:${provider.file.path}|scale:${provider.scale}';
    }
    if (provider is XNZAssetImageProvider) {
      return 'asset:${provider.assetName}|package:${provider.package}|scale:${provider.scale}|avif:${provider.avifOverrideDurationMs}';
    }
    if (provider is AssetImage) {
      return 'asset:${provider.assetName}|package:${provider.package}';
    }
    if (provider is ExactAssetImage) {
      return 'asset:${provider.assetName}|package:${provider.package}|scale:${provider.scale}';
    }
    if (provider is XNZMemoryImageProvider) {
      return 'memory:${Object.hashAll(provider.bytes)}|scale:${provider.scale}|avif:${provider.avifOverrideDurationMs}';
    }
    if (provider is MemoryImage) {
      return 'memory:${Object.hashAll(provider.bytes)}|scale:${provider.scale}';
    }
    return null;
  }

  static int? _avifOverrideDuration(ImageProvider provider) {
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

  static double _imageScale(ImageProvider provider) {
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

  static XNZImageSourceType? _sourceTypeOf(ImageProvider provider) {
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

  static Uri? _uriOfProvider(ImageProvider provider) {
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

  static Map<String, Object?> _providerOptions(ImageProvider provider) {
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
}
