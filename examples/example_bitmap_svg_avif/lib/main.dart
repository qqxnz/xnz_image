import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xnz_image/xnz_image.dart';
import 'package:xnz_image_avif/xnz_image_avif.dart';
import 'package:xnz_image_svg/xnz_image_svg.dart';

const _demoBitmapUrl = 'https://picsum.photos/400/240';
const _demoAvifUrl = 'https://ezgif.com/images/format-demo/butterfly.avif';
const _demoSvgUrl = 'https://api.iconify.design/circle-flags/zh.svg';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        ],
      ),
    );
  }
}
