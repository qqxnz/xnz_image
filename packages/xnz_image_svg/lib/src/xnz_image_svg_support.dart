import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:xnz_image/xnz_image.dart';

import 'xnz_svg_utils.dart';

class XNZImageSvg implements XNZImageSupport {
  @override
  String get id => 'svg';

  @override
  int get priority => 100;

  @override
  bool canHandle(XNZImageRequest request) {
    if (request.bytes != null && isSvgBytes(request.bytes!)) {
      return true;
    }
    final path = request.uri?.path;
    if (path == null || path.isEmpty) {
      return false;
    }
    return isLikelySvgPath(path);
  }

  @override
  XNZImageBuildResult? resolve(XNZImageRequest request) {
    final width = request.option('width') as double?;
    final height = request.option('height') as double?;
    final fit = request.option('fit') as BoxFit? ?? BoxFit.contain;
    final color = request.option('color') as Color?;
    final colorFilter = svgColorFilterFromColor(color);

    switch (request.sourceType) {
      case XNZImageSourceType.network:
      case XNZImageSourceType.memory:
        final bytes = request.bytes;
        if (bytes == null || !isSvgBytes(bytes)) {
          return null;
        }
        return XNZImageBuildResult.widget(
          widget: SvgPicture.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            colorFilter: colorFilter,
          ),
          format: 'svg',
        );
      case XNZImageSourceType.file:
        final path = request.uri?.toFilePath();
        if (path == null || path.isEmpty || !isLikelySvgPath(path)) {
          return null;
        }
        return XNZImageBuildResult.widget(
          widget: SvgPicture.file(
            File(path),
            width: width,
            height: height,
            fit: fit,
            colorFilter: colorFilter,
          ),
          format: 'svg',
        );
      case XNZImageSourceType.asset:
        final assetName = request.option('assetName') as String?;
        if (assetName == null || !isLikelySvgPath(assetName)) {
          return null;
        }
        return XNZImageBuildResult.widget(
          widget: SvgPicture.asset(
            assetName,
            bundle: request.option('bundle') as AssetBundle?,
            package: request.option('package') as String?,
            width: width,
            height: height,
            fit: fit,
            colorFilter: colorFilter,
          ),
          format: 'svg',
        );
    }
  }
}
