import 'dart:ui' as ui;
import 'package:flutter/material.dart';

int _viewCounter = 0;

Widget buildWebImage({
  required String url,
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
  Widget? errorWidget,
}) {
  return Image.network(
    url,
    width: width,
    height: height,
    fit: fit,
    errorBuilder: (_, __, ___) => errorWidget ?? const SizedBox.shrink(),
  );
}

String _normalizeCloudinaryUrl(String url) {
  try {
    const marker = '/upload/';
    final idx = url.indexOf(marker);
    if (idx == -1) return url;

    final before = url.substring(0, idx + marker.length);
    final after = url.substring(idx + marker.length);

    if (after.startsWith('f_auto') || after.contains('/f_auto')) return url;

    return '${before}f_auto,q_auto/$after';
  } catch (_) {
    return url;
  }
}

String _cssFit(BoxFit fit) {
  switch (fit) {
    case BoxFit.cover:
      return 'cover';
    case BoxFit.contain:
      return 'contain';
    case BoxFit.fill:
      return 'fill';
    case BoxFit.scaleDown:
      return 'scale-down';
    case BoxFit.none:
      return 'none';
    default:
      return 'cover';
  }
}

Widget _placeholder(double? width, double? height, Widget? errorWidget) {
  return errorWidget ??
      Container(
        width: width,
        height: height,
        color: Colors.grey[850],
        child: const Icon(Icons.broken_image, color: Colors.white38, size: 40),
      );
}
