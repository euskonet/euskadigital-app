import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// Muestra contenido HTML de un feed con la tipografía de la app.
class HtmlBody extends StatelessWidget {
  const HtmlBody(this.html, {super.key});
  final String html;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HtmlWidget(
      html,
      textStyle: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
      customStylesBuilder: (el) {
        if (el.localName == 'a') {
          final c = theme.colorScheme.primary;
          return {'color': '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}'};
        }
        if (el.localName == 'img') return {'border-radius': '12px'};
        return null;
      },
      onTapUrl: (url) async {
        final uri = Uri.tryParse(url);
        if (uri == null) return false;
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    );
  }
}
