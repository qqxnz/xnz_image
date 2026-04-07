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
  static const String _demoUrl = 'https://picsum.photos/800/480';
  static const String _errorUrl = 'https://invalid-host/image.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('XnzNetCacheImage Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'XNZCacheImage (with callbacks)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          XNZCacheImage(
            url: _demoUrl,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
            progressIndicatorBuilder: (progress) {
              return Container(
                width: double.infinity,
                height: 180,
                color: const Color(0xFFE8F3FF),
                alignment: Alignment.center,
                child: Text('Loading ${(progress * 100).toStringAsFixed(0)}%'),
              );
            },
            imageBuilder: (context, imageProvider) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image(
                  image: imageProvider,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              );
            },
            loadFailedBuilder: (url, error) {
              return Container(
                width: double.infinity,
                height: 180,
                color: const Color(0xFFFFECE8),
                alignment: Alignment.center,
                child: Text('Load failed:\n$url'),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Image + XNZCacheImageProvider',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image(
              image: XNZCacheImageProvider(_demoUrl),
              width: double.infinity,
              height: 180,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'XNZCacheImage (error callback demo)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          XNZCacheImage(
            url: _errorUrl,
            width: double.infinity,
            height: 120,
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
