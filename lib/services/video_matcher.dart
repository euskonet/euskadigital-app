import '../models/episode.dart';
import 'feed_parser.dart';

/// Empareja un episodio de podcast con su versión en vídeo de YouTube.
///
/// 1. Por número de episodio: «Gaming Room #135» ↔ «… - Gaming Room #135».
/// 2. Por el resto del título, quitando el nombre del programa y el número:
///    «CiberTxoko 007 – Josep Albors (ESET)» ↔ «Josep Albors (ESET): "…"».
class VideoMatcher {
  VideoMatcher._();

  /// Devuelve el identificador de vídeo de YouTube o `null`.
  static String? match(Episode episode, String programTitle, List<Episode> videos) {
    if (videos.isEmpty) return null;
    final program = normalize(programTitle);
    final number = episodeNumber(episode.title, programTitle);

    if (number != null) {
      for (final v in videos) {
        if (episodeNumber(v.title, programTitle) == number) return FeedParser.youtubeVideoId(v);
      }
    }

    // Variantes del título: completo, sin lo que va entre paréntesis y lo de
    // dentro de los paréntesis («Miguel Ángel Durán (midudev)» → «midudev»).
    final probes = <String>{};
    void add(String text, int minLength) {
      final c = _core(text, program);
      if (c.length >= minLength) probes.add(c.length > 24 ? c.substring(0, 24) : c);
    }

    add(episode.title, 8);
    add(episode.title.replaceAll(RegExp(r'\([^)]*\)'), ''), 8);
    for (final m in RegExp(r'\(([^)]*)\)').allMatches(episode.title)) {
      add(m.group(1)!, 6);
    }
    for (final probe in probes) {
      for (final v in videos) {
        if (normalize(v.title).contains(probe)) return FeedParser.youtubeVideoId(v);
      }
    }
    return null;
  }

  /// Número de episodio: «#135», «Gaming Room 135», «CiberTxoko 007»…
  static int? episodeNumber(String title, String programTitle) {
    final hash = RegExp(r'#\s*(\d{1,4})\b').firstMatch(title);
    if (hash != null) return int.parse(hash.group(1)!);
    final name = RegExp.escape(programTitle).replaceAll(r'\ ', r'\s*');
    final after = RegExp('$name\\s*[-–:#]?\\s*(\\d{1,4})\\b', caseSensitive: false).firstMatch(title);
    return after == null ? null : int.parse(after.group(1)!);
  }

  /// Título sin el nombre del programa ni números ni signos.
  static String _core(String title, String normalizedProgram) {
    var t = normalize(title).replaceAll(RegExp(r'\d+'), '');
    if (normalizedProgram.isNotEmpty) t = t.replaceAll(normalizedProgram, '');
    return t;
  }

  static String normalize(String s) {
    const from = 'áàäâéèëêíìïîóòöôúùüûñç';
    const to = 'aaaaeeeeiiiioooouuuunc';
    final b = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final i = from.indexOf(ch);
      final c = i >= 0 ? to[i] : ch;
      if (RegExp(r'[a-z0-9]').hasMatch(c)) b.write(c);
    }
    return b.toString();
  }
}
