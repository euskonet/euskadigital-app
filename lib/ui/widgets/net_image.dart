import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Imagen de internet con caché en disco ([CachedNetworkImage]).
///
/// En las pruebas y en la generación de capturas no hay caché de disco, así
/// que [debugProvider] permite servir las imágenes desde ficheros locales.
class NetImage extends StatelessWidget {
  const NetImage({
    super.key,
    required this.imageUrl,
    this.fit,
    this.width,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.placeholder,
    this.errorWidget,
    this.imageBuilder,
  });

  final String imageUrl;
  final BoxFit? fit;
  final double? width;
  final Duration fadeInDuration;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, Object)? errorWidget;
  final Widget Function(BuildContext, ImageProvider)? imageBuilder;

  /// Solo para pruebas: devuelve la imagen local de una URL, o `null` si no
  /// la hay (se muestra entonces [errorWidget]).
  static ImageProvider? Function(String url)? debugProvider;

  @override
  Widget build(BuildContext context) {
    final override = debugProvider;
    if (override != null) {
      final provider = override(imageUrl);
      if (provider == null) {
        return errorWidget?.call(context, imageUrl, 'sin imagen') ?? const SizedBox.shrink();
      }
      if (imageBuilder != null) return imageBuilder!(context, provider);
      return Image(
        image: provider,
        fit: fit,
        width: width,
        errorBuilder: (c, e, _) => errorWidget?.call(c, imageUrl, e) ?? const SizedBox.shrink(),
      );
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      fadeInDuration: fadeInDuration,
      placeholder: placeholder,
      errorWidget: errorWidget,
      imageBuilder: imageBuilder,
    );
  }
}
