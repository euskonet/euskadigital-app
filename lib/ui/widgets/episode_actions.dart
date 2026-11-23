import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/app_config.dart';
import '../../models/episode.dart';
import '../../services/download_manager.dart';
import '../../services/feed_repository.dart';
import '../../services/library_store.dart';
import '../../services/player_service.dart';

/// Portada y nombre del programa de un episodio.
class EpisodeVisuals {
  EpisodeVisuals(this.imageUrl, this.fallbackAsset, this.programTitle);
  final String? imageUrl;
  final String? fallbackAsset;
  final String programTitle;

  static EpisodeVisuals of(BuildContext context, Episode e, {bool listen = false}) {
    final config = context.read<AppConfig>();
    final feeds = listen ? context.watch<FeedRepository>() : context.read<FeedRepository>();
    final program = config.programById(e.feedId);
    return EpisodeVisuals(
      e.imageUrl ?? feeds.programImage(e.feedId),
      program?.fallbackImage,
      program?.title ?? config.name,
    );
  }
}

/// Acciones comunes sobre episodios, con mensajes al usuario.
class EpisodeActions {
  static void play(BuildContext context, Episode e) {
    final v = EpisodeVisuals.of(context, e);
    context.read<PlayerService>().playEpisode(
          e,
          programTitle: v.programTitle,
          fallbackImage: v.fallbackAsset,
          programImage: v.imageUrl,
        );
  }

  static Future<void> toggleDownload(BuildContext context, Episode e) async {
    final dm = context.read<DownloadManager>();
    final lib = context.read<LibraryStore>();
    final messenger = ScaffoldMessenger.of(context);
    if (dm.isDownloading(e.id)) {
      dm.cancel(e.id);
      return;
    }
    if (lib.isDownloaded(e.id)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Borrar descarga?'),
          content: Text('Se eliminará «${e.title}» de este dispositivo.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar')),
          ],
        ),
      );
      if (ok == true) await dm.delete(e.id);
      return;
    }
    try {
      await dm.download(e);
      if (lib.isDownloaded(e.id)) {
        messenger.showSnackBar(SnackBar(content: Text('Descargado: ${e.title}')));
      }
    } on DownloadBlockedException catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(err.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('No se ha podido descargar el episodio.')));
    }
  }

  static void share(BuildContext context, Episode e, {String? programTitle}) {
    final link = e.link ?? e.audioUrl ?? '';
    final prefix = programTitle == null ? '' : '$programTitle · ';
    SharePlus.instance.share(ShareParams(text: '$prefix${e.title}\n$link', subject: e.title));
  }
}
