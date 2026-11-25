import 'package:flutter/material.dart';

/// Título de cabecera común a las pestañas principales.
class BrandTitle extends StatelessWidget {
  const BrandTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800));
  }
}

/// Cabecera compacta de las pestañas principales (Inicio, Programas,
/// Noticias, Más), igual en todas.
class BrandSliverAppBar extends StatelessWidget {
  const BrandSliverAppBar(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(floating: true, titleSpacing: 20, title: BrandTitle(title));
  }
}
