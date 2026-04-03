import 'package:flutter/material.dart';

/// A reusable network image widget with configurable loading and error states.
class XnzNetCacheImage extends StatelessWidget {
  const XnzNetCacheImage({
    required this.imageUrl,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }

        return SizedBox(
          width: width,
          height: height,
          child: placeholder ??
              const ColoredBox(
                color: Color(0xFFECEFF3),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return SizedBox(
          width: width,
          height: height,
          child: errorWidget ??
              const ColoredBox(
                color: Color(0xFFFBEAEA),
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Color(0xFFB44343),
                  ),
                ),
              ),
        );
      },
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }
}

