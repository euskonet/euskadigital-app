import 'package:xml/xml.dart';

import '../models/episode.dart';

/// Lector de feeds RSS 2.0 (con extensiones iTunes/Media) y Atom.
class FeedParser {
  static ParsedFeed parse(String xmlText, {required String feedId}) {
    final doc = XmlDocument.parse(xmlText.trimLeft());
    final root = doc.rootElement;
    if (root.name.local == 'feed') return _parseAtom(root, feedId);
    final channel = _child(root, 'channel') ?? root;
    return _parseRss(channel, feedId);
  }

  // ---------------------------------------------------------------- RSS

  static ParsedFeed _parseRss(XmlElement ch, String feedId) {
    final channelImage = _attr(_child(ch, 'image', ns: 'itunes'), 'href') ??
        _text(_child(_child(ch, 'image'), 'url'));

    final channel = FeedChannel(
      title: _text(_child(ch, 'title')) ?? '',
      description: _text(_child(ch, 'summary', ns: 'itunes')) ??
          _text(_child(ch, 'description')),
      imageUrl: channelImage,
      author: _text(_child(ch, 'author', ns: 'itunes')),
      link: _text(_child(ch, 'link')),
    );

    final items = <Episode>[];
    for (final it in _children(ch, 'item')) {
      final enclosure = _children(it, 'enclosure').firstWhere(
        (e) => (_attr(e, 'type') ?? '').startsWith('audio') || _attr(e, 'url') != null,
        orElse: () => XmlElement(XmlName('none')),
      );
      final audioUrl = _attr(enclosure, 'url');
      final audioType = _attr(enclosure, 'type');
      final isAudio = audioUrl != null &&
          (audioType == null || audioType.startsWith('audio') || _looksLikeAudio(audioUrl));

      final description = _text(_child(it, 'description')) ??
          _text(_child(it, 'summary', ns: 'itunes'));
      final content = _text(_child(it, 'encoded', ns: 'content'));
      final link = _text(_child(it, 'link'));
      final guid = _text(_child(it, 'guid'));

      final image = _attr(_child(it, 'image', ns: 'itunes'), 'href') ??
          _mediaImage(it) ??
          (!isAudio && audioUrl != null && (audioType ?? '').startsWith('image')
              ? audioUrl
              : null) ??
          firstImageInHtml(content ?? description ?? '');

      items.add(Episode(
        id: guid ?? (isAudio ? audioUrl : null) ?? link ?? '${feedId}_${items.length}',
        feedId: feedId,
        title: _clean(_text(_child(it, 'title')) ?? 'Sin título'),
        description: description,
        content: content,
        link: link,
        pubDate: parseDate(_text(_child(it, 'pubDate')) ?? _text(_child(it, 'date', ns: 'dc'))),
        audioUrl: isAudio ? audioUrl : null,
        audioType: isAudio ? audioType : null,
        duration: parseDuration(_text(_child(it, 'duration', ns: 'itunes'))),
        imageUrl: image,
        author: _text(_child(it, 'author', ns: 'itunes')) ?? _text(_child(it, 'creator', ns: 'dc')),
      ));
    }
    return ParsedFeed(channel: channel, items: items);
  }

  // --------------------------------------------------------------- Atom

  static ParsedFeed _parseAtom(XmlElement feed, String feedId) {
    String? linkOf(XmlElement e, {String rel = 'alternate'}) {
      for (final l in _children(e, 'link')) {
        if ((_attr(l, 'rel') ?? 'alternate') == rel) return _attr(l, 'href');
      }
      return null;
    }

    final channel = FeedChannel(
      title: _text(_child(feed, 'title')) ?? '',
      description: _text(_child(feed, 'subtitle')),
      imageUrl: _text(_child(feed, 'logo')) ?? _text(_child(feed, 'icon')),
      link: linkOf(feed),
    );
    final items = <Episode>[];
    for (final e in _children(feed, 'entry')) {
      final content = _text(_child(e, 'content'));
      final summary = _text(_child(e, 'summary'));
      final enclosure = linkOf(e, rel: 'enclosure');
      items.add(Episode(
        id: _text(_child(e, 'id')) ?? linkOf(e) ?? '${feedId}_${items.length}',
        feedId: feedId,
        title: _clean(_text(_child(e, 'title')) ?? 'Sin título'),
        description: summary,
        content: content,
        link: linkOf(e),
        pubDate: parseDate(_text(_child(e, 'published')) ?? _text(_child(e, 'updated'))),
        audioUrl: enclosure,
        imageUrl: _mediaImage(e) ?? firstImageInHtml(content ?? summary ?? ''),
        author: _text(_child(_child(e, 'author'), 'name')),
      ));
    }
    return ParsedFeed(channel: channel, items: items);
  }

  // ------------------------------------------------------------ helpers

  static const _nsUris = {
    'itunes': 'http://www.itunes.com/dtds/podcast-1.0.dtd',
    'content': 'http://purl.org/rss/1.0/modules/content/',
    'media': 'http://search.yahoo.com/mrss/',
    'dc': 'http://purl.org/dc/elements/1.1/',
  };

  static bool _matches(XmlElement e, String local, String? ns) {
    if (e.name.local != local) return false;
    if (ns == null) return e.name.prefix == null || e.name.namespaceUri == null;
    return e.name.prefix == ns || e.name.namespaceUri == _nsUris[ns];
  }

  static Iterable<XmlElement> _children(XmlElement? e, String local, {String? ns}) =>
      e == null ? const [] : e.childElements.where((c) => _matches(c, local, ns));

  static XmlElement? _child(XmlElement? e, String local, {String? ns}) {
    final it = _children(e, local, ns: ns);
    return it.isEmpty ? null : it.first;
  }

  static String? _text(XmlElement? e) {
    if (e == null) return null;
    final t = e.innerText.trim();
    return t.isEmpty ? null : t;
  }

  static String? _attr(XmlElement? e, String name) {
    final v = e?.getAttribute(name)?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  static String? _mediaImage(XmlElement it) {
    final thumb = _attr(_child(it, 'thumbnail', ns: 'media'), 'url');
    if (thumb != null) return thumb;
    for (final m in _children(it, 'content', ns: 'media')) {
      final type = _attr(m, 'type') ?? '';
      final medium = _attr(m, 'medium') ?? '';
      if (type.startsWith('image') || medium == 'image') return _attr(m, 'url');
    }
    return null;
  }

  static bool _looksLikeAudio(String url) =>
      RegExp(r'\.(mp3|m4a|aac|ogg|opus|wav)(\?|$)', caseSensitive: false).hasMatch(url);

  static String _clean(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Devuelve la URL de la primera imagen `<img src>` de un HTML.
  static String? firstImageInHtml(String html) {
    final m = RegExp("<img[^>]+src=[\"']([^\"']+)[\"']", caseSensitive: false)
        .firstMatch(html);
    final src = m?.group(1);
    if (src == null || src.startsWith('data:')) return null;
    return src;
  }

  /// Elimina etiquetas HTML y entidades básicas para mostrar un extracto.
  static String stripHtml(String html) {
    var s = html
        .replaceAll(RegExp(r'<(script|style)[^>]*>.*?</\1>', dotAll: true, caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<br\s*/?>|</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    const entities = {
      '&nbsp;': ' ', '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"',
      '&#39;': "'", '&apos;': "'", '&hellip;': '…', '&#8230;': '…',
      '&ntilde;': 'ñ', '&aacute;': 'á', '&eacute;': 'é', '&iacute;': 'í',
      '&oacute;': 'ó', '&uacute;': 'ú', '&#8217;': '’', '&#8220;': '“', '&#8221;': '”',
    };
    entities.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)));
    return s.replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(RegExp(r'\s*\n\s*'), '\n').trim();
  }

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  /// Fechas RFC 822 (RSS) e ISO 8601 (Atom).
  static DateTime? parseDate(String? s) {
    if (s == null) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    final m = RegExp(
      r'(\d{1,2})\s+([A-Za-z]{3})[a-z]*\s+(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|[A-Z]{1,4})?',
    ).firstMatch(s);
    if (m == null) return null;
    final month = _months[m[2]!.toLowerCase()];
    if (month == null) return null;
    var year = int.parse(m[3]!);
    if (year < 100) year += 2000;
    var dt = DateTime.utc(year, month, int.parse(m[1]!), int.parse(m[4]!),
        int.parse(m[5]!), int.tryParse(m[6] ?? '') ?? 0);
    final tz = m[7];
    if (tz != null && (tz.startsWith('+') || tz.startsWith('-'))) {
      final sign = tz.startsWith('-') ? -1 : 1;
      final offset = Duration(
          hours: int.parse(tz.substring(1, 3)), minutes: int.parse(tz.substring(3, 5)));
      dt = sign > 0 ? dt.subtract(offset) : dt.add(offset);
    } else if (tz != null) {
      const zones = {'EST': -5, 'EDT': -4, 'CST': -6, 'CDT': -5, 'MST': -7, 'MDT': -6, 'PST': -8, 'PDT': -7, 'CET': 1, 'CEST': 2};
      final h = zones[tz];
      if (h != null) dt = dt.subtract(Duration(hours: h));
    }
    return dt;
  }

  /// `HH:MM:SS`, `MM:SS` o segundos.
  static Duration? parseDuration(String? s) {
    if (s == null) return null;
    final parts = s.trim().split(':').map((p) => int.tryParse(p.trim())).toList();
    if (parts.any((p) => p == null) || parts.isEmpty || parts.length > 3) return null;
    var secs = 0;
    for (final p in parts) {
      secs = secs * 60 + p!;
    }
    return secs > 0 ? Duration(seconds: secs) : null;
  }
}
