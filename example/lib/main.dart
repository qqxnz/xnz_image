import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:xnz_net_cache_image/xnz_net_cache_image.dart';

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
  // 一个 1x1 PNG 像素的示例 bytes，可替换为你自己的 Uint8List 图片数据。
  final Uint8List _memoryPngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('XnzNetCacheImage Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'XNZNetworkImage (with callbacks)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const XNZNetworkImage(
            imageUrl: 'https://ezgif.com/images/format-demo/butterfly.avif',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          const Text(
            'Image + XNZNetworkImageProvider',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Image(
            image: XNZNetworkImageProvider(
                'https://ezgif.com/images/format-demo/butterfly.avif'),
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          const Text(
            'XNZMemoryImage (from Uint8List bytes)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          XNZMemoryImage(
            bytes: _memoryPngBytes,
            width: 120,
            height: 120,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          const Text(
            'Image + XNZMemoryImageProvider',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Image(
            image: XNZMemoryImageProvider(_memoryPngBytes),
            width: 120,
            height: 120,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          const Text(
            'XNZNetworkImage (error callback demo)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          XNZNetworkImage(
            imageUrl: 'https://sssa',
            width: 200,
            height: 200,
            loadFailedBuilder: (url, error) {
              return Container(
                width: double.infinity,
                height: 120,
                color: const Color(0xFFFFECE8),
                alignment: Alignment.center,
                child: const Text('error callback triggered'),
              );
            },
          ),
        ],
      ),
    );
  }
}
