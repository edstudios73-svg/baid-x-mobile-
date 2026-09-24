import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url?.trim() ?? '';
    if (imageUrl.isEmpty) {
      return _fallback(width, height);
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, _) => _fallback(width, height),
      errorWidget: (_, _, _) => _fallback(width, height),
    );
  }

  Widget _fallback(double? width, double? height) {
    return ColoredBox(
      color: AppColors.line,
      child: SizedBox(
        width: width,
        height: height,
        child: const Icon(Icons.image_outlined, color: AppColors.textMuted),
      ),
    );
  }
}
