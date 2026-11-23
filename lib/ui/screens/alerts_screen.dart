import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../services/alerts_store.dart';
import '../../services/feed_repository.dart';
import '../widgets/artwork.dart';

/// Muestra el resultado de activar/desactivar avisos.
void showAlertResult(BuildContext context, AlertToggleResult r, {String? programTitle}) {
  final text = switch (r) {
    AlertToggleResult.enabled =>
      programTitle == null ? 'Avisos activados' : 'Te avisaremos de los episodios nuevos de $programTitle',
    AlertToggleResult.disabled => programTitle == null ? 'Avisos desactivados' : 'Avisos de $programTitle desactivados',
    AlertToggleResult.permissionDenied =>
      'Para recibir avisos, permite las notificaciones de EuskaDigital en los ajustes del móvil.',
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Campana para activar los avisos de un programa.
class AlertBellButton extends StatelessWidget {
  const AlertBellButton({super.key, required this.program});
  final ProgramConfig program;

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<AlertsStore>();
    final on = alerts.isOn(program.id);
    return IconButton(
      tooltip: on ? 'Desactivar avisos' : 'Avisarme de episodios nuevos',
      isSelected: on,
      onPressed: () async {
        final r = await context.read<AlertsStore>().toggle(program.id);
        if (context.mounted) showAlertResult(context, r, programTitle: program.title);
      },
      icon: const Icon(Icons.notifications_none_rounded),
      selectedIcon: const Icon(Icons.notifications_active_rounded),
    );
  }
}

/// Ajustes → Avisos de episodios nuevos.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.read<AppConfig>();
    final alerts = context.watch<AlertsStore>();
    final feeds = context.watch<FeedRepository>();
    final theme = Theme.of(context);
    final all = config.allPrograms.map((p) => p.id);
    final allOn = alerts.count == config.allPrograms.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Avisos de episodios')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              'Recibe una notificación cuando un programa publique un episodio nuevo. '
              'El móvil revisa los programas cada pocas horas, así que el aviso puede tardar un poco.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          SwitchListTile(
            title: const Text('Todos los programas'),
            value: allOn,
            onChanged: (v) async {
              final r = await context.read<AlertsStore>().setAll(all, v);
              if (context.mounted) showAlertResult(context, r);
            },
          ),
          for (final group in config.programGroups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(group.title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
            ),
            for (final p in group.programs)
              SwitchListTile(
                secondary: Artwork(url: feeds.programImage(p.id), fallbackAsset: p.fallbackImage, size: 40, radius: 8),
                title: Text(p.title),
                value: alerts.isOn(p.id),
                onChanged: (_) async {
                  final r = await context.read<AlertsStore>().toggle(p.id);
                  if (context.mounted && r == AlertToggleResult.permissionDenied) showAlertResult(context, r);
                },
              ),
          ],
        ],
      ),
    );
  }
}
