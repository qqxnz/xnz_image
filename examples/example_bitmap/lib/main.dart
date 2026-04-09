import 'package:flutter/material.dart';
import 'package:xnz_image/xnz_image.dart';

const _demoBitmapUrl = 'https://picsum.photos/400/240';
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
        ],
      ),
    );
  }
}
