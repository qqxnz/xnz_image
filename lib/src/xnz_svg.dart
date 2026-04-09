import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

bool isLikelySvgPath(String path) {
  final lowercasePath = path.toLowerCase();
  return lowercasePath.endsWith('.svg') || lowercasePath.endsWith('.svgz');
}

bool isLikelySvgUrl(String url) {
  final path = Uri.tryParse(url)?.path ?? url;
  return isLikelySvgPath(path);
}

bool isSvgBytes(Uint8List bytes) {
  if (bytes.isEmpty) return false;

  final sampleLength = bytes.length > 2048 ? 2048 : bytes.length;
  final sample =
      utf8.decode(bytes.sublist(0, sampleLength), allowMalformed: true);
  final normalized = sample.trimLeft().toLowerCase();

  return normalized.contains('<svg') || normalized.startsWith('<?xml');
}

ColorFilter? svgColorFilterFromColor(Color? color) {
  if (color == null) return null;
  return ColorFilter.mode(color, BlendMode.srcIn);
}
