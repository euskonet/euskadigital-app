import 'dart:io';

import 'package:euskadigital/services/feed_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RSS con extensiones iTunes', () {
    final feed = FeedParser.parse(
      File('test/fixtures/podcast.xml').readAsStringSync(),
      feedId: 'enredando',
    );

    test('lee los datos del canal', () {
      expect(feed.channel.title, 'EnRedAndo');
      expect(feed.channel.author, 'EuskaDigital');
      expect(feed.channel.imageUrl, 'https://example.com/enredando.jpg');
    });

    test('lee episodios con audio, duración, imagen y fecha', () {
      final e = feed.items.first;
      expect(e.id, 'enredando-120');
      expect(e.feedId, 'enredando');
      expect(e.title, 'Episodio 120: Inteligencia artificial');
      expect(e.audioUrl, 'https://example.com/120.mp3');
      expect(e.duration, const Duration(hours: 1, minutes: 2, seconds: 3));
      expect(e.imageUrl, 'https://example.com/120.jpg');
      expect(e.pubDate, DateTime.utc(2025, 6, 10, 16, 30));
      expect(e.body, contains('Notas completas'));
    });

    test('usa la URL del audio como id si no hay guid', () {
      final e = feed.items[1];
      expect(e.id, 'https://example.com/119.mp3');
      expect(e.duration, const Duration(seconds: 2730));
      expect(e.pubDate, DateTime.utc(2025, 6, 2, 10));
    });

    test('las entradas sin audio usan la primera imagen del HTML', () {
      final e = feed.items[2];
      expect(e.hasAudio, isFalse);
      expect(e.imageUrl, 'https://example.com/post.png');
      expect(e.author, 'Redacción');
    });
  });

  test('lee feeds Atom', () {
    const atom = '''<?xml version="1.0"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Noticias</title>
  <entry>
    <id>tag:1</id>
    <title>Hola</title>
    <link rel="alternate" href="https://example.com/hola"/>
    <link rel="enclosure" href="https://example.com/hola.mp3"/>
    <published>2025-01-15T09:00:00Z</published>
    <summary>Resumen</summary>
  </entry>
</feed>''';
    final feed = FeedParser.parse(atom, feedId: 'news');
    expect(feed.channel.title, 'Noticias');
    expect(feed.items.single.link, 'https://example.com/hola');
    expect(feed.items.single.audioUrl, 'https://example.com/hola.mp3');
    expect(feed.items.single.pubDate, DateTime.utc(2025, 1, 15, 9));
  });

  group('utilidades', () {
    test('parseDuration', () {
      expect(FeedParser.parseDuration('45:10'), const Duration(minutes: 45, seconds: 10));
      expect(FeedParser.parseDuration('abc'), isNull);
      expect(FeedParser.parseDuration(null), isNull);
    });

    test('stripHtml', () {
      expect(FeedParser.stripHtml('<p>Hola&nbsp;<b>mundo</b> &amp; &#8230;</p>'), 'Hola mundo & …');
    });
  });
}
