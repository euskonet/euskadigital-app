import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import 'settings_screen.dart';
import 'twitch_screen.dart';
import 'webview_screen.dart';

/// Enlaces, redes sociales, ajustes y acerca de.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static IconData _icon(String? name) => switch (name) {
        'calendar' => Icons.calendar_month_rounded,
        'web' => Icons.language_rounded,
        'twitch' => Icons.live_tv_rounded,
        'youtube' => Icons.smart_display_outlined,
        'x' => Icons.alternate_email_rounded,
        'facebook' => Icons.facebook_rounded,
        'feedback' => Icons.mail_outline_rounded,
        'privacy' => Icons.privacy_tip_outlined,
        _ => Icons.link_rounded,
      };

  void _open(BuildContext context, LinkConfig link) {
    final twitch = context.read<AppConfig>().twitch;
    if (link.id == 'twitch' && twitch != null) {
      TwitchScreen.open(context, twitch);
    } else if (link.inApp) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WebViewScreen(title: link.title, url: link.url),
      ));
    } else {
      launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    final theme = Theme.of(context);
    final main = config.links.where((l) => l.id == 'schedule' || l.id == 'web').toList();
    const appLinks = {'contact', 'privacy'};
    final social = config.links.where((l) => l.id != 'schedule' && l.id != 'web' && !appLinks.contains(l.id)).toList();
    final contact = config.links.where((l) => appLinks.contains(l.id)).toList();

    Widget group(String title, List<Widget> children) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
              ),
              Card(child: Column(children: children)),
            ],
          ),
        );

    ListTile tile(LinkConfig l) => ListTile(
          leading: Icon(_icon(l.icon)),
          title: Text(l.title),
          subtitle: l.subtitle == null ? null : Text(l.subtitle!),
          trailing: Icon(l.inApp ? Icons.chevron_right_rounded : Icons.open_in_new_rounded, size: 20),
          onTap: () => _open(context, l),
        );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverAppBar.large(title: Text('Más')),
          SliverList.list(children: [
            group('EuskaDigital', [for (final l in main) tile(l)]),
            group('Síguenos', [for (final l in social) tile(l)]),
            group('App', [
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Ajustes'),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
              ),
              for (final l in contact) tile(l),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('Acerca de'),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: config.name,
                  applicationVersion: 'Versión 3.0',
                  applicationIcon: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset('assets/branding/logo.png', width: 56, height: 56),
                  ),
                  children: [
                    const Text('Radio online, podcasts y noticias de tecnología.'),
                    const SizedBox(height: 12),
                    SelectableText('Contacto: ${config.contactEmail}'),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 24),
          ]),
        ],
      ),
    );
  }
}
