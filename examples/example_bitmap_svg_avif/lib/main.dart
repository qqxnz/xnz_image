import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xnz_image/xnz_image.dart';
import 'package:xnz_image_avif/xnz_image_avif.dart';
import 'package:xnz_image_svg/xnz_image_svg.dart';

const _demoBitmapUrl = 'https://picsum.photos/400/240';
const _demoAnimatedUrl = 'https://www.gstatic.com/webp/animated/1.webp';
const _demoAvifUrl = 'https://ezgif.com/images/format-demo/butterfly.avif';
const _demoSvgUrl = 'https://api.iconify.design/circle-flags/zh.svg';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  XNZImageLogs.showLogs = true;
  XNZImageMemoryObserver().init();
  XNZImage.support(XNZImageSvg());
  XNZImage.support(XNZImageAvif());
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'XNZImage Bitmap+SVG+AVIF Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F6EFD)),
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  Uint8List? _memoryAvifBytes;
  File? _demoAvifFile;
  bool _isPreparingFile = true;

  @override
  void initState() {
    super.initState();
    _prepareDemoFile();
  }

  Future<void> _prepareDemoFile() async {
    setState(() {
      _isPreparingFile = true;
    });
    try {
      final byteData = await rootBundle.load('assets/butterfly.avif');
      final bytes = byteData.buffer.asUint8List();
      final file = File('${Directory.systemTemp.path}/butterfly.avif');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() {
        _memoryAvifBytes = bytes;
        _demoAvifFile = file;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _memoryAvifBytes = null;
        _demoAvifFile = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingFile = false;
        });
      }
    }
  }

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

  Widget _loadingState() {
    if (_isPreparingFile) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return const Text('AVIF demo file unavailable.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('4. Bitmap + SVG + AVIF')),
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
            title: 'XNZNetworkImage (SVG)',
            description: 'SVG URL 渲染。',
            child: const XNZNetworkImage(
              imageUrl: _demoSvgUrl,
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
          _section(
            context: context,
            title: 'XNZAssetImage (SVG)',
            description: '本地 SVG 资源渲染。',
            child: const XNZAssetImage(
              assetName: 'assets/fire.svg',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
          _section(
            context: context,
            title: 'XNZNetworkImage (AVIF)',
            description: 'AVIF URL 渲染。',
            child: const XNZNetworkImage(
              imageUrl: _demoAvifUrl,
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
          _section(
            context: context,
            title: 'XNZMemoryImage (AVIF bytes)',
            description: 'AVIF 内存字节渲染。',
            child: _memoryAvifBytes != null
                ? XNZMemoryImage(
                    bytes: _memoryAvifBytes!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  )
                : _loadingState(),
          ),
          _section(
            context: context,
            title: 'XNZFileImage (AVIF file)',
            description: 'AVIF 本地文件渲染。',
            child: _demoAvifFile != null
                ? XNZFileImage(
                    file: _demoAvifFile!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  )
                : _loadingState(),
          ),
          _section(
            context: context,
            title: 'XNZAnimatedImage (Animated WebP)',
            description: '动画位图示例：支持播放控制、循环和进度同步。',
            child: _AnimatedPreview(
              image: XNZNetworkImageProvider(_demoAnimatedUrl),
            ),
          ),
          _section(
            context: context,
            title: 'XNZAnimatedImage (AVIF)',
            description: '注册 AVIF support 后，自动识别并按 AVIF 动画解码。',
            child: _AnimatedPreview(
              image: XNZNetworkImageProvider(
                _demoAvifUrl,
                avifOverrideDurationMs: -1,
              ),
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
