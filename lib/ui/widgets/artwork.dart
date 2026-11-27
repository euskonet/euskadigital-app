import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'net_image.dart';

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
    this.natural = false,
  });

  final String? url;
  final String? fallbackAsset;
  final IconData fallbackIcon;
  final double? size;
  final double radius;
  final Object? heroTag;

  /// El recuadro toma la proporción de la imagen en lugar de ser cuadrado
  /// (reproductor). En listas se deja cuadrado para que las filas cuadren.
  final bool natural;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget iconBox() => Container(
          color: scheme.primaryContainer,
          child: Center(child: Icon(fallbackIcon, color: scheme.onPrimaryContainer)),
        );

    Widget fitted(ImageProvider provider) => natural
        ? _NaturalImage(provider: provider, radius: radius)
        : _FittedImage(provider: provider, background: scheme.surfaceContainerHighest);

    Widget fallback() => fallbackAsset != null ? fitted(AssetImage(fallbackAsset!)) : iconBox();

    Widget img = (url == null || url!.isEmpty)
        ? fallback()
        : NetImage(
            imageUrl: url!,
            fadeInDuration: const Duration(milliseconds: 200),
            imageBuilder: (_, provider) => fitted(provider),
            placeholder: (_, _) => natural
                ? const SizedBox.shrink()
                : Container(color: scheme.surfaceContainerHighest),
            errorWidget: (_, _, _) => fallback(),
          );

    if (!natural) {
      img = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: AspectRatio(aspectRatio: 1, child: img),
      );
    }
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

/// Imagen con su propia proporción y esquinas redondeadas: lee el tamaño de
/// la imagen y ajusta el recuadro a él.
class _NaturalImage extends StatefulWidget {
  const _NaturalImage({required this.provider, required this.radius});
  final ImageProvider provider;
  final double radius;

  @override
  State<_NaturalImage> createState() => _NaturalImageState();
}

class _NaturalImageState extends State<_NaturalImage> {
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener((info, _) {
    final ratio = info.image.width / info.image.height;
    if (mounted && ratio != _ratio) setState(() => _ratio = ratio);
  });
  double? _ratio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _NaturalImage old) {
    super.didUpdateWidget(old);
    if (old.provider != widget.provider) _resolve();
  }

  void _resolve() {
    final stream = widget.provider.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = _ratio;
    if (ratio == null) return const SizedBox.shrink();
    return AspectRatio(
      aspectRatio: ratio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: Image(image: widget.provider, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
      ),
    );
  }
}
