import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xnz_net_cache_image/xnz_net_cache_image.dart';

const _demoImageUrl = 'https://ezgif.com/images/format-demo/butterfly.avif';
const _invalidDemoImageUrl = 'https://sssa';

void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'XnzNetCacheImage Demo',
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

  Widget _previewBox(Widget child) {
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
            _previewBox(child),
          ],
        ),
      ),
    );
  }

  Widget _fileLoadingState() {
    if (_isPreparingFile) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
          SizedBox(height: 8),
          Text('Loading demo file...'),
        ],
      );
    }
    return const Text('Demo file unavailable. Please check assets config.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('XnzNetCacheImage Demo'),
        actions: [
          IconButton(
            tooltip: 'Reload local file demo',
            onPressed: _prepareDemoFile,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            title: 'XNZNetworkImage',
            description: '直接通过 URL 加载网络图片，支持下载进度与失败态回调。',
            child: const XNZNetworkImage(
              imageUrl: _demoImageUrl,
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
          _section(
            title: 'Image + XNZNetworkImageProvider',
            description: '在原生 Image 组件中组合使用 NetworkImageProvider。',
            child: Image(
              image: XNZNetworkImageProvider(_demoImageUrl),
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
          ),
          _section(
            title: 'XNZMemoryImage',
            description: '使用 assets/butterfly.avif 的内存字节流渲染图片。',
            child: _memoryAvifBytes != null
                ? XNZMemoryImage(
                    bytes: _memoryAvifBytes!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  )
                : _fileLoadingState(),
          ),
          _section(
            title: 'Image + XNZMemoryImageProvider',
            description: '将 assets/butterfly.avif 内存数据以 ImageProvider 方式接入。',
            child: _memoryAvifBytes != null
                ? Image(
                    image: XNZMemoryImageProvider(_memoryAvifBytes!),
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  )
                : _fileLoadingState(),
          ),
          _section(
            title: 'XNZFileImage',
            description: '从本地 File 渲染图片（本示例从 assets 写入临时目录）。',
            child: _demoAvifFile != null
                ? XNZFileImage(
                    file: _demoAvifFile!,
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  )
                : _fileLoadingState(),
          ),
          _section(
            title: 'Image + XNZFileImageProvider',
            description: '将 File 作为 ImageProvider 接入原生 Image 组件。',
            child: _demoAvifFile != null
                ? Image(
                    image: XNZFileImageProvider(_demoAvifFile!),
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                  )
                : _fileLoadingState(),
          ),
          _section(
            title: 'Error Callback Demo',
            description: '演示网络请求失败时 loadFailedBuilder 的回调效果。',
            child: XNZNetworkImage(
              imageUrl: _invalidDemoImageUrl,
              width: 200,
              height: 200,
              loadFailedBuilder: (url, error) {
                return Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECE8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text('error callback triggered'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
