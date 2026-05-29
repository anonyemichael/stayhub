import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SchoolLogo extends StatelessWidget {
  final String? logoUrl;
  final double size;
  final BoxFit fit;
  final bool hasBackground;

  const SchoolLogo({
    super.key,
    required this.logoUrl,
    this.size = 22,
    this.fit = BoxFit.contain,
    this.hasBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget image;
    
    if (logoUrl == null || logoUrl!.isEmpty) {
      image = _buildPlaceholder();
    } else if (logoUrl!.startsWith('assets/')) {
      image = Image.asset(
        logoUrl!,
        width: size,
        height: size,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    } else {
      image = CachedNetworkImage(
        imageUrl: logoUrl!,
        width: size,
        height: size,
        fit: fit,
        placeholder: (context, url) => SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(strokeWidth: 1),
        ),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }

    if (!hasBackground) return image;

    return Container(
      width: size + 4,
      height: size + 4,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Center(child: image),
    );
  }

  Widget _buildPlaceholder() {
    return Icon(Icons.school, size: size * 0.8, color: Colors.grey);
  }
}
