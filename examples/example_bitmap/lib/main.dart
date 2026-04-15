import 'package:flutter/material.dart';
import 'package:xnz_image/xnz_image.dart';

const _demoBitmapUrl = 'https://picsum.photos/400/240';
const _demoAnimatedAsset = 'assets/giphy.gif';
const _demoAnimatedGifUrl =
    'https://media4.giphy.com/media/v1.Y2lkPTc5MGI3NjExNHM5NHowNnVyYmd5amM5MTJsejg5eWJmM3dsM2hpMXR1dDNjMTB0eiZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/uo6a2SrS7ZVVYc79bA/giphy.gif';
const _invalidDemoImageUrl = 'https://sssa';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  XNZImageLogs.showLogs = true;
  XNZImageMemoryObserver().init();
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'XNZImage Bitmap Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F6EFD)),
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  Widget _previewBox(BuildContext context, Widget child) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _section({
    required BuildContext context,
    required String title,
    required String description,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _previewBox(context, child),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('1. Bitmap')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            context: context,
            title: 'XNZNetworkImage (Bitmap)',
            description: '位图 URL 渲染。',
            child: const XNZNetworkImage(
              imageUrl: _demoBitmapUrl,
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
          _section(
            context: context,
            title: 'Image + XNZNetworkImageProvider',
            description: '原生 Image + 位图 Provider。',
            child: Image(
              image: XNZNetworkImageProvider(_demoBitmapUrl),
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
          _section(
            context: context,
            title: 'XNZAssetImage (Bitmap)',
            description: '本地位图资源渲染。',
            child: const XNZAssetImage(
              assetName: 'assets/tg.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
          _section(
            context: context,
            title: 'Error Callback Demo',
            description: '失败回调示例。',
            child: XNZNetworkImage(
              imageUrl: _invalidDemoImageUrl,
              width: 200,
              height: 200,
              loadFailedBuilder: (url, error) {
                return const Text('error callback triggered');
              },
            ),
          ),
          _section(
            context: context,
            title: 'XNZAnimatedImage (GIF Asset)',
            description: '动画位图示例：支持暂停、继续、重播、循环与进度同步。',
            child: const _AnimatedPreview(
              image: XNZAssetImageProvider(_demoAnimatedAsset),
            ),
          ),
          _section(
            context: context,
            title: 'XNZAnimatedImage (GIF Network)',
            description: '网络 GIF 动画示例。',
            child: _AnimatedPreview(
              image: XNZNetworkImageProvider(_demoAnimatedGifUrl),
            ),
          ),
          _section(
            context: context,
            title: 'XNZAnimatedImage (Static PNG)',
            description: '使用动画组件加载非动画图片（单帧）示例。',
            child: const _AnimatedPreview(
              image: XNZAssetImageProvider('assets/tg.png'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedPreview extends StatefulWidget {
  const _AnimatedPreview({required this.image});

  final ImageProvider image;

  @override
  State<_AnimatedPreview> createState() => _AnimatedPreviewState();
}

class _AnimatedPreviewState extends State<_AnimatedPreview> {
  final XNZAnimatedImageController _controller = XNZAnimatedImageController();
  bool _loop = true;
  int _fps = 0;
  int _frameCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 180,
          height: 120,
          child: XNZAnimatedImage(
            image: widget.image,
            controller: _controller,
            loop: _loop,
            fit: BoxFit.contain,
            onLoaded: (duration, fps, frameCount) {
              if (!mounted) return;
              setState(() {
                _fps = fps;
                _frameCount = frameCount;
              });
            },
            loadingBuilder: (_) =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Text('Animated image load failed'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final durationMs = _controller.duration.inMilliseconds;
            final positionMs = _controller.position.inMilliseconds;
            return Text(
              'frame ${_controller.frameIndex + 1}/$_frameCount · '
              'fps $_fps · ${positionMs}ms/${durationMs}ms',
              style: Theme.of(context).textTheme.bodySmall,
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Play',
              onPressed: _controller.play,
              icon: const Icon(Icons.play_arrow),
            ),
            IconButton(
              tooltip: 'Pause',
              onPressed: _controller.pause,
              icon: const Icon(Icons.pause),
            ),
            IconButton(
              tooltip: 'Replay',
              onPressed: _controller.replay,
              icon: const Icon(Icons.replay),
            ),
            const Text('Loop'),
            Switch(
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              value: _loop,
              onChanged: (value) {
                setState(() {
                  _loop = value;
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}
