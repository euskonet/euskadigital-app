import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Portada en un hueco cuadrado con esquinas redondeadas.
///
/// La imagen se muestra **entera, con su proporción original** (no se
/// recorta). Si no es cuadrada, el espacio sobrante se rellena con una
/// versión desenfocada de la propia imagen. Usa la imagen remota si existe
/// y, si no (o si falla), la imagen local de respaldo.
class Artwork extends StatelessWidget {
  const Artwork({
    super.key,
    this.url,
    this.fallbackAsset,
    this.fallbackIcon = Icons.podcasts_rounded,
    this.size,
    this.radius = 12,
    this.heroTag,
  });

  final String? url;
  final String? fallbackAsset;
  final IconData fallbackIcon;
  final double? size;
  final double radius;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget iconBox() => Container(
          color: scheme.primaryContainer,
          child: Center(child: Icon(fallbackIcon, color: scheme.onPrimaryContainer)),
        );

    Widget fitted(ImageProvider provider) => _FittedImage(provider: provider, background: scheme.surfaceContainerHighest);

    Widget fallback() => fallbackAsset != null ? fitted(AssetImage(fallbackAsset!)) : iconBox();

    Widget img = (url == null || url!.isEmpty)
        ? fallback()
        : CachedNetworkImage(
            imageUrl: url!,
            fadeInDuration: const Duration(milliseconds: 200),
            imageBuilder: (_, provider) => fitted(provider),
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

/// Imagen completa (`contain`) sobre un fondo desenfocado de sí misma.
class _FittedImage extends StatelessWidget {
  const _FittedImage({required this.provider, required this.background});
  final ImageProvider provider;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: background),
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12, tileMode: TileMode.clamp),
          child: Opacity(
            opacity: 0.55,
            child: Image(image: provider, fit: BoxFit.cover, filterQuality: FilterQuality.low),
          ),
        ),
        Image(image: provider, fit: BoxFit.contain, filterQuality: FilterQuality.medium),
      ],
    );
  }
}
