import 'dart:async';
import 'dart:collection';
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
import 'xnz_network_bytes_loader.dart';

/// Decoder signature used by [XNZAnimatedImage] for custom frame decoding.
typedef XNZAnimatedImageDecoder = Future<Object?> Function(
  XNZAnimatedImageDecodeRequest request,
);

/// Decode request passed to [XNZAnimatedImageDecoder].
@immutable
class XNZAnimatedImageDecodeRequest {
  /// Creates a decode request.
  const XNZAnimatedImageDecodeRequest({
    required this.image,
    required this.bytes,
    required this.scale,
    this.avifOverrideDurationMs,
  });

  /// Source image provider.
  final ImageProvider image;

  /// Raw bytes resolved from [image].
  final Uint8List bytes;

  /// Render scale used for decoded frames.
  final double scale;

  /// Optional per-frame duration override used by AVIF decoders.
  final int? avifOverrideDurationMs;
}

/// A single decoded animation frame.
@immutable
class XNZAnimatedImageFrame {
  /// Creates a frame.
  const XNZAnimatedImageFrame({
    required this.image,
    required this.duration,
    this.scale = 1.0,
  });

  /// Frame bitmap.
  final ui.Image image;

  /// Frame display duration.
  final Duration duration;

  /// Frame scale.
  final double scale;
}

/// Fully decoded animation payload.
@immutable
class XNZAnimatedImageData {
  /// Creates decoded animation data.
  const XNZAnimatedImageData({
    required this.frames,
    required this.duration,
  });

  /// Ordered frame list.
  final List<XNZAnimatedImageFrame> frames;

  /// Total animation duration.
  final Duration duration;
}

/// In-memory cache for decoded animated images.
@immutable
class XNZAnimatedImageCache {
  /// Creates an animated image cache with bounded entry count.
  XNZAnimatedImageCache({this.maxEntries = 64})
      : assert(maxEntries > 0, 'maxEntries must be greater than zero');

  /// Maximum number of cached animated entries.
  final int maxEntries;

  /// Cached animations indexed by provider-derived key.
  final LinkedHashMap<String, XNZAnimatedImageData> caches =
      LinkedHashMap<String, XNZAnimatedImageData>();

  /// Returns a cached entry and refreshes its recency.
  XNZAnimatedImageData? get(String key) {
    final value = caches.remove(key);
    if (value == null) {
      return null;
    }
    caches[key] = value;
    return value;
  }

  /// Stores a cache entry and evicts least-recently-used entries when needed.
  void set(String key, XNZAnimatedImageData data) {
    final previous = caches.remove(key);
    if (previous != null && !identical(previous, data)) {
      _disposeData(previous);
    }
    caches[key] = data;
    _evictOverflowIfNeeded();
  }

  /// Clears all cached animations and disposes frame images.
  void clear() {
    for (final cached in caches.values) {
      _disposeData(cached);
    }
    caches.clear();
  }

  /// Removes a cached animation and disposes its frame images.
  ///
  /// Returns `true` if the entry existed.
  bool evict(Object key) {
    final removed = caches.remove(key);
    if (removed == null) {
      return false;
    }
    _disposeData(removed);
    return true;
  }

  void _evictOverflowIfNeeded() {
    while (caches.length > maxEntries) {
      final oldestKey = caches.keys.first;
      final removed = caches.remove(oldestKey);
      if (removed != null) {
        _disposeData(removed);
      }
    }
  }

  static void _disposeData(XNZAnimatedImageData data) {
    for (final frame in data.frames) {
      frame.image.dispose();
    }
  }
}

/// Controller for playback state and commands of [XNZAnimatedImage].
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

  /// Current playback position within a loop.
  Duration get position => _position;

  /// Single-loop duration.
  Duration get duration => _duration;

  /// Current frame index.
  int get frameIndex => _frameIndex;

  /// Number of completed loops.
  int get completedLoops => _completedLoops;

  /// Whether playback is currently running.
  bool get isPlaying => _isPlaying;

  /// Whether non-looping playback has completed.
  bool get isCompleted => _isCompleted;

  /// Normalized progress in range `0.0..1.0`.
  double get progress {
    final totalMs = _duration.inMilliseconds;
    if (totalMs <= 0) {
      return 0;
    }
    return (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  /// Starts playback.
  void play() => _playCallback?.call();

  /// Pauses playback.
  void pause() => _pauseCallback?.call();

  /// Resumes playback from current position.
  void resume() => _resumeCallback?.call();

  /// Restarts playback from first frame.
  void replay() => _replayCallback?.call();

  /// Binds command callbacks from an owning widget state.
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

  /// Unbinds all command callbacks.
  void unbind() {
    _playCallback = null;
    _pauseCallback = null;
    _resumeCallback = null;
    _replayCallback = null;
  }

  /// Synchronizes exposed playback state and notifies listeners on change.
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

/// Widget that renders and controls animated image playback.
@immutable
class XNZAnimatedImage extends StatefulWidget {
  /// Creates an [XNZAnimatedImage].
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

  /// Global decode cache for animated image data.
  static XNZAnimatedImageCache cache = XNZAnimatedImageCache();

  /// Source image provider.
  final ImageProvider image;

  /// Optional external playback controller.
  final XNZAnimatedImageController? controller;

  /// Builder shown while first frame is loading.
  final Widget Function(BuildContext context)? loadingBuilder;

  /// Builder shown when load/decode fails.
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace? stackTrace,
  )? errorBuilder;

  /// Callback invoked after frames are loaded.
  final void Function(Duration duration, int fps, int frameCount)? onLoaded;

  /// Callback invoked when each loop completes.
  final void Function(int completedLoops)? onCompleted;

  /// Optional custom decoder.
  final XNZAnimatedImageDecoder? decoder;

  /// Whether to start playback automatically after load.
  final bool autoPlay;

  /// Whether playback repeats indefinitely.
  final bool loop;

  /// Whether decoded animation data should be cached.
  final bool useCache;

  /// Target width.
  final double? width;

  /// Target height.
  final double? height;

  /// Optional color filter.
  final Color? color;

  /// Blend mode for [color].
  final BlendMode? colorBlendMode;

  /// Box fit for rendered frame.
  final BoxFit? fit;

  /// How to align the image within its bounds.
  final AlignmentGeometry alignment;

  /// How to paint repeated image tiles.
  final ImageRepeat repeat;

  /// Optional center slice for 9-patch like stretching.
  final Rect? centerSlice;

  /// Whether to mirror horizontally in RTL contexts.
  final bool matchTextDirection;

  /// Semantic label for accessibility.
  final String? semanticLabel;

  /// Whether to exclude semantics for this widget.
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
    _disposeCurrentFramesIfOwned();
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

  void _disposeFrames(List<XNZAnimatedImageFrame> frames) {
    for (final frame in frames) {
      frame.image.dispose();
    }
  }

  void _disposeCurrentFramesIfOwned() {
    if (_frames.isEmpty) {
      return;
    }
    _disposeFrames(_frames);
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
      var decodedFromCache = false;
      if (widget.useCache && key != null) {
        final cached = XNZAnimatedImage.cache.get(key);
        if (cached != null) {
          decoded = _cloneDecodedData(cached);
          decodedFromCache = true;
        }
      }
      decoded ??= await _decodeImage(widget.image);

      if (!mounted || loadToken != _loadToken) {
        _disposeFrames(decoded.frames);
        return;
      }

      if (widget.useCache && key != null) {
        if (!decodedFromCache) {
          final existing = XNZAnimatedImage.cache.get(key);
          if (existing == null) {
            // Cache owns decoded handles; widget uses cloned handles.
            XNZAnimatedImage.cache.set(key, decoded);
            decoded = _cloneDecodedData(decoded);
          } else {
            // Another loader inserted into cache first.
            _disposeFrames(decoded.frames);
            decoded = _cloneDecodedData(existing);
          }
        }
      }

      final frameEndMs = <int>[];
      var totalMs = 0;
      for (final frame in decoded.frames) {
        final frameMs = frame.duration.inMilliseconds;
        totalMs += frameMs <= 0 ? 1 : frameMs;
        frameEndMs.add(totalMs);
      }
      final isStatic = decoded.frames.length <= 1;

      final previousFrames = _frames;
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
      if (previousFrames.isNotEmpty) {
        _disposeFrames(previousFrames);
      }

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

  static XNZAnimatedImageData _cloneDecodedData(XNZAnimatedImageData data) {
    final frames = data.frames
        .map(
          (frame) => XNZAnimatedImageFrame(
            image: frame.image.clone(),
            duration: frame.duration,
            scale: frame.scale,
          ),
        )
        .toList(growable: false);
    return XNZAnimatedImageData(frames: frames, duration: data.duration);
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
      final request = XNZUrlRequest(
        provider.imageUrl,
        headers: provider.headers,
        includeHeadersInCacheKey: provider.includeHeadersInCacheKey,
      );
      final cached = await XNZCacheManager().getCache(request);
      if (cached != null) {
        return cached;
      }
      return xnzLoadNetworkBytes(
        Uri.parse(provider.imageUrl),
        headers: provider.headers,
        includeHeadersInCacheKey: provider.includeHeadersInCacheKey,
      );
    }
    if (provider is NetworkImage) {
      return xnzLoadNetworkBytes(
        Uri.parse(provider.url),
        headers: provider.headers,
        includeHeadersInCacheKey:
            provider.headers != null && provider.headers!.isNotEmpty,
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

  static String? _cacheKey(ImageProvider provider) {
    if (provider is XNZNetworkImageProvider) {
      return 'network:${provider.imageUrl}|scale:${provider.scale}|avif:${provider.avifOverrideDurationMs}';
    }
    if (provider is NetworkImage) {
      final headerEntries = provider.headers?.entries.toList()
        ?..sort((a, b) => a.key.compareTo(b.key));
      final headersHash = headerEntries == null
          ? 0
          : Object.hashAll(
              headerEntries.map((entry) => Object.hash(entry.key, entry.value)),
            );
      return 'network:${provider.url}|scale:${provider.scale}|headers:$headersHash';
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
