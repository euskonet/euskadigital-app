import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Portada cuadrada con esquinas redondeadas. Usa la imagen remota si
/// existe y, si no (o si falla), la imagen local de respaldo.
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    this.url,
    this.fallbackAsset,
    this.size,
    this.radius = 12,
    this.heroTag,
  });

  final String? url;
  final String? fallbackAsset;
  final double? size;
  final double radius;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget fallback() => fallbackAsset != null
        ? Image.asset(fallbackAsset!, fit: BoxFit.cover, filterQuality: FilterQuality.medium)
        : Container(
            color: scheme.primaryContainer,
            child: Icon(Icons.podcasts_rounded, color: scheme.onPrimaryContainer),
          );

    Widget img = (url == null || url!.isEmpty)
        ? fallback()
        : CachedNetworkImage(
            imageUrl: url!,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (_, _) => Container(color: scheme.surfaceContainerHighest),
            errorWidget: (_, _, _) => fallback(),
          );

    img = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: AspectRatio(aspectRatio: 1, child: img),
    );
    if (size != null) img = SizedBox.square(dimension: size, child: img);
    if (heroTag != null) img = Hero(tag: heroTag!, child: img);
    return img;
  }
}
