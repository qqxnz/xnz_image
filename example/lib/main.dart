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
  final TextEditingController _urlController = TextEditingController(
    text: 'https://picsum.photos/800/480',
  );

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('XnzNetCacheImage Demo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Image URL',
            ),
            onSubmitted: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => setState(() {}),
            child: const Text('Reload'),
          ),
          const SizedBox(height: 20),
          const Text(
            'Default',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          XnzNetCacheImage(
            imageUrl: _urlController.text,
            width: double.infinity,
            height: 180,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(height: 20),
          const Text(
            'Custom Placeholder & Error',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          XnzNetCacheImage(
            imageUrl: 'https://invalid-host/image.png',
            width: double.infinity,
            height: 180,
            borderRadius: BorderRadius.circular(12),
            placeholder: const ColoredBox(
              color: Color(0xFFE8F3FF),
              child: Center(child: Text('Loading...')),
            ),
            errorWidget: const ColoredBox(
              color: Color(0xFFFFF1E9),
              child: Center(child: Text('Failed to load')),
            ),
          ),
        ],
      ),
    );
  }
}

