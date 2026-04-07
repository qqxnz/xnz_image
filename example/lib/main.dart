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
          const XNZCacheImage(
            url: 'https://ezgif.com/images/format-demo/butterfly.avif',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          const Text(
            'Image + XNZCacheImageProvider',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Image(
            image: XNZCacheImageProvider(
                'https://ezgif.com/images/format-demo/butterfly.avif'),
            width: 200,
            height: 200,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 20),
          const Text(
            'XNZCacheImage (error callback demo)',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          XNZCacheImage(
            url: 'https://sssa',
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
