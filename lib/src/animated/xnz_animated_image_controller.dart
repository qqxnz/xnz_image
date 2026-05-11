import 'package:flutter/foundation.dart';

/// Controller for playback state and commands of animated image widgets.
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
