import 'dart:io';

import 'package:euskadigital/services/feed_parser.dart';
import 'package:euskadigital/services/video_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List parse(String f, String id) => FeedParser.parse(File('test/fixtures/$f').readAsStringSync(), feedId: id).items;

  test('números de episodio', () {
    expect(VideoMatcher.episodeNumber('Ocarina of Time – Gaming Room #135', 'Gaming Room'), 135);
    expect(VideoMatcher.episodeNumber('CiberTxoko 007 – Josep Albors (ESET)', 'CiberTxoko'), 7);
    expect(VideoMatcher.episodeNumber('Josep Albors (ESET): "El candadito"', 'CiberTxoko'), isNull);
  });

  for (final (program, title) in [('gaming-room', 'Gaming Room'), ('cibertxoko', 'CiberTxoko')]) {
    test('empareja los episodios de $title con sus vídeos', () {
      final episodes = parse('podcast-$program.xml', program).where((e) => e.hasAudio).toList();
      final videos = [...parse('video-$program.xml', 'video-$program'), ...parse('youtube.xml', 'youtube')].cast();
      final matched = <String, String?>{
        for (final e in episodes) e.title: VideoMatcher.match(e, title, videos.cast()),
      };
      // ignore: avoid_print
      matched.forEach((k, v) => print('$title | ${v ?? '—'} | $k'));
      final found = matched.values.whereType<String>().toList();
      expect(found, isNotEmpty);
      expect(found.toSet().length, found.length, reason: 'cada vídeo debe emparejarse con un solo episodio');
      if (program == 'cibertxoko') expect(found, hasLength(7), reason: 'los 7 episodios tienen vídeo');
    });
  }
}
