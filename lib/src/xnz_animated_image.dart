import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'animated/xnz_animated_decoder.dart';
import 'animated/xnz_animated_image_cache.dart';
import 'animated/xnz_animated_image_cache_key.dart';
import 'animated/xnz_animated_image_controller.dart';
import 'animated/xnz_animated_image_loader.dart';
import 'animated/xnz_animated_image_models.dart';
import 'animated/xnz_animated_provider_context.dart';

export 'animated/xnz_animated_image_cache.dart' show XNZAnimatedImageCache;
export 'animated/xnz_animated_image_controller.dart'
    show XNZAnimatedImageController;
export 'animated/xnz_animated_image_models.dart'
    show
        XNZAnimatedImageData,
        XNZAnimatedImageDecodeRequest,
        XNZAnimatedImageDecoder,
        XNZAnimatedImageFrame;

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
    _disposeCurrentFramesIfOwned();
    _frames = const <XNZAnimatedImageFrame>[];
    _frameEndMs = const <int>[];
    _duration = Duration.zero;
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
      final key = xnzAnimatedCacheKeyForProvider(widget.image);
      XNZAnimatedImageData? decoded;
      var decodedFromCache = false;
      if (widget.useCache && key != null) {
        final cached = XNZAnimatedImage.cache.get(key);
        if (cached != null) {
          // Cache keeps original frame handles. Each consumer must clone to
          // avoid disposing cache-owned images during widget lifecycle changes.
          decoded = xnzCloneAnimatedDecodedData(cached);
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
            // Cache owns decoded handles; widget side always works on clones.
            XNZAnimatedImage.cache.set(key, decoded);
            decoded = xnzCloneAnimatedDecodedData(decoded);
          } else {
            // Another loader inserted into cache first.
            _disposeFrames(decoded.frames);
            decoded = xnzCloneAnimatedDecodedData(existing);
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
      _ticker.stop();
      _disposeCurrentFramesIfOwned();
      setState(() {
        _frames = const <XNZAnimatedImageFrame>[];
        _frameEndMs = const <int>[];
        _duration = Duration.zero;
        _frameIndex = 0;
        _position = Duration.zero;
        _sessionStartPositionMs = 0;
        _sessionStartLoopCount = 0;
        _isPlaying = false;
        _isCompleted = false;
        _completedLoops = 0;
        _loadError = e;
        _loadErrorStackTrace = st;
      });
      _syncControllerState();
    }
  }

  Future<XNZAnimatedImageData> _decodeImage(ImageProvider provider) async {
    final bytes = await xnzLoadBytesFromProvider(provider);
    final request = XNZAnimatedImageDecodeRequest(
      image: provider,
      bytes: bytes,
      scale: xnzAnimatedImageScale(provider),
      avifOverrideDurationMs: xnzAnimatedAvifOverrideDuration(provider),
    );

    final supportDecoder = xnzResolveSupportAnimatedDecoder(
      provider: provider,
      bytes: bytes,
      scale: request.scale,
      avifOverrideDurationMs: request.avifOverrideDurationMs,
    );
    final effectiveDecoder = widget.decoder ?? supportDecoder;
    final customDecodedRaw = await effectiveDecoder?.call(request);
    final customDecoded = xnzCoerceAnimatedDecodedData(customDecodedRaw);
    if (customDecoded != null) {
      return customDecoded;
    }
    return xnzDefaultDecodeAnimatedImage(request);
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
    // Playback timeline is modeled as an infinite elapsed clock:
    // loop count = elapsed ~/ total, position = elapsed % total.
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
}
