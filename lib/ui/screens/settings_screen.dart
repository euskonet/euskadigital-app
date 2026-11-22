import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/alerts_store.dart';
import '../../services/download_manager.dart';
import '../../services/library_store.dart';
import '../../services/settings_store.dart';
import '../format.dart';
import 'alerts_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<int> _used = context.read<DownloadManager>().usedBytes();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final lib = context.watch<LibraryStore>();
    final theme = Theme.of(context);

    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(t, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          header('Apariencia'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('Sistema')),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Claro')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Oscuro')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.themeMode = s.first,
            ),
          ),
          header('Avisos'),
          Builder(builder: (context) {
            final n = context.watch<AlertsStore>().count;
            return ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Episodios nuevos'),
              subtitle: Text(n == 0 ? 'Desactivados' : n == 1 ? '1 programa' : '$n programas'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AlertsScreen())),
            );
          }),
          header('Descargas'),
          SwitchListTile(
            title: const Text('Descargar solo con wifi'),
            subtitle: const Text('Evita gastar datos móviles'),
            value: settings.wifiOnlyDownloads,
            onChanged: (v) => settings.wifiOnlyDownloads = v,
          ),
          FutureBuilder<int>(
            future: _used,
            builder: (context, snap) => ListTile(
              title: const Text('Borrar todas las descargas'),
              subtitle: Text('${lib.downloads.length} episodios · ${formatBytes(snap.data ?? 0)}'),
              trailing: const Icon(Icons.delete_outline_rounded),
              enabled: lib.downloads.isNotEmpty,
              onTap: () async {
                final dm = context.read<DownloadManager>();
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('¿Borrar todas las descargas?'),
                    content: const Text('Tendrás que volver a descargar los episodios para escucharlos sin conexión.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                      FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar')),
                    ],
                  ),
                );
                if (ok == true) {
                  await dm.deleteAll();
                  setState(() => _used = dm.usedBytes());
                }
              },
            ),
          ),
          header('Privacidad'),
          const ListTile(
            title: Text('Sin publicidad ni seguimiento'),
            subtitle: Text('Tus favoritos, historial y descargas se guardan solo en este dispositivo.'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
