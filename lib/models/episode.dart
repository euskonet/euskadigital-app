/// Un elemento de un feed: episodio de podcast o noticia.
class Episode {
  const Episode({
    required this.id,
    required this.feedId,
    required this.title,
    this.description,
    this.content,
    this.link,
    this.pubDate,
    this.audioUrl,
    this.audioType,
    this.duration,
    this.imageUrl,
    this.author,
  });

  /// Identificador estable (guid del feed, o URL del audio / enlace).
  final String id;

  /// Programa al que pertenece (o `news` para noticias).
  final String feedId;
  final String title;

  /// Resumen (puede contener HTML).
  final String? description;

  /// Contenido completo (`content:encoded`), si existe.
  final String? content;
  final String? link;
  final DateTime? pubDate;
  final String? audioUrl;
  final String? audioType;
  final Duration? duration;
  final String? imageUrl;
  final String? author;

  bool get hasAudio => audioUrl != null && audioUrl!.isNotEmpty;

  /// El cuerpo más completo disponible.
  String get body => (content?.isNotEmpty ?? false) ? content! : (description ?? '');

  Episode copyWith({String? imageUrl}) => Episode(
        id: id,
        feedId: feedId,
        title: title,
        description: description,
        content: content,
        link: link,
        pubDate: pubDate,
        audioUrl: audioUrl,
        audioType: audioType,
        duration: duration,
        imageUrl: imageUrl ?? this.imageUrl,
        author: author,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'feedId': feedId,
        'title': title,
        if (description != null) 'description': description,
        if (link != null) 'link': link,
        if (pubDate != null) 'pubDate': pubDate!.toIso8601String(),
        if (audioUrl != null) 'audioUrl': audioUrl,
        if (audioType != null) 'audioType': audioType,
        if (duration != null) 'duration': duration!.inSeconds,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (author != null) 'author': author,
      };

  factory Episode.fromJson(Map<String, dynamic> j) => Episode(
        id: j['id'] as String,
        feedId: j['feedId'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        link: j['link'] as String?,
        pubDate: j['pubDate'] == null ? null : DateTime.tryParse(j['pubDate'] as String),
        audioUrl: j['audioUrl'] as String?,
        audioType: j['audioType'] as String?,
        duration: j['duration'] == null ? null : Duration(seconds: j['duration'] as int),
        imageUrl: j['imageUrl'] as String?,
        author: j['author'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Episode && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Datos de cabecera de un feed (canal).
class FeedChannel {
  const FeedChannel({
    required this.title,
    this.description,
    this.imageUrl,
    this.author,
    this.link,
  });

  final String title;
  final String? description;
  final String? imageUrl;
  final String? author;
  final String? link;
}

class ParsedFeed {
  const ParsedFeed({required this.channel, required this.items});
  final FeedChannel channel;
  final List<Episode> items;
}
