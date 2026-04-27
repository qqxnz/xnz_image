import 'package:flutter/material.dart';
import 'package:xnz_image/xnz_image.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'xnz_image example',
      home: Scaffold(
        appBar: AppBar(title: const Text('xnz_image Example')),
        body: const Center(
          child: XNZNetworkImage(
            imageUrl: 'https://picsum.photos/300/200',
            width: 300,
            height: 200,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
