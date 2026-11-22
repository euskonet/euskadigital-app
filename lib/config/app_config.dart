import 'dart:convert';

import 'package:flutter/services.dart';

/// Configuración estática de la app (programas, directo, enlaces).
/// Se carga desde `assets/config/app_config.json`.
class AppConfig {
  AppConfig({
    required this.name,
    required this.contactEmail,
    required this.live,
    this.twitch,
    required this.news,
    required this.programGroups,
    required this.links,
  });

  final String name;
  final String contactEmail;
  final LiveConfig live;
  final TwitchConfig? twitch;
  final NewsConfig news;
  final List<ProgramGroup> programGroups;
  final List<LinkConfig> links;

  List<ProgramConfig> get allPrograms =>
      [for (final g in programGroups) ...g.programs];

  ProgramConfig? programById(String id) {
    for (final p in allPrograms) {
      if (p.id == id) return p;
    }
    return null;
  }

  static Future<AppConfig> load() async {
    final raw = await rootBundle.loadString('assets/config/app_config.json');
    return AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        name: j['name'] as String,
        contactEmail: j['contactEmail'] as String,
        live: LiveConfig.fromJson(j['live'] as Map<String, dynamic>),
        twitch: j['twitch'] == null ? null : TwitchConfig.fromJson(j['twitch'] as Map<String, dynamic>),
        news: NewsConfig.fromJson(j['news'] as Map<String, dynamic>),
        programGroups: [
          for (final g in j['programGroups'] as List)
            ProgramGroup.fromJson(g as Map<String, dynamic>)
        ],
        links: [
          for (final l in j['links'] as List)
            LinkConfig.fromJson(l as Map<String, dynamic>)
        ],
      );
}

class LiveConfig {
  LiveConfig({
    required this.title,
    required this.subtitle,
    required this.streams,
    this.offAirText,
  });

  final String title;
  final String subtitle;
  /// En orden de preferencia: el primero es el principal y el resto, respaldo.
  final List<LiveStream> streams;
  final String? offAirText;

  factory LiveConfig.fromJson(Map<String, dynamic> j) => LiveConfig(
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        offAirText: j['offAirText'] as String?,
        streams: [
          for (final s in j['streams'] as List)
            LiveStream.fromJson(s as Map<String, dynamic>)
        ],
      );
}

class LiveStream {
  LiveStream({required this.id, required this.label, required this.url});
  final String id;
  final String label;
  final String url;

  factory LiveStream.fromJson(Map<String, dynamic> j) => LiveStream(
        id: j['id'] as String,
        label: j['label'] as String,
        url: j['url'] as String,
      );
}

/// Canal de Twitch integrado (reproductor + chat).
class TwitchConfig {
  TwitchConfig({required this.channel, required this.parentDomain, required this.title, this.subtitle});

  final String channel;

  /// Dominio que se declara a Twitch como página que inserta el reproductor
  /// (parámetro `parent` obligatorio de los embeds de Twitch).
  final String parentDomain;
  final String title;
  final String? subtitle;

  String get channelUrl => 'https://www.twitch.tv/$channel';

  factory TwitchConfig.fromJson(Map<String, dynamic> j) => TwitchConfig(
        channel: j['channel'] as String,
        parentDomain: j['parentDomain'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String?,
      );
}

class NewsConfig {
  NewsConfig({required this.title, required this.feedUrl});
  final String title;
  final String feedUrl;

  factory NewsConfig.fromJson(Map<String, dynamic> j) =>
      NewsConfig(title: j['title'] as String, feedUrl: j['feedUrl'] as String);
}

class ProgramGroup {
  ProgramGroup({required this.title, required this.programs});
  final String title;
  final List<ProgramConfig> programs;

  factory ProgramGroup.fromJson(Map<String, dynamic> j) => ProgramGroup(
        title: j['title'] as String,
        programs: [
          for (final p in j['programs'] as List)
            ProgramConfig.fromJson(p as Map<String, dynamic>)
        ],
      );
}

class ProgramConfig {
  ProgramConfig({
    required this.id,
    required this.title,
    required this.feedUrl,
    this.fallbackImage,
  });

  final String id;
  final String title;
  final String feedUrl;

  /// Imagen local (asset) que se usa si el feed no trae portada.
  final String? fallbackImage;

  factory ProgramConfig.fromJson(Map<String, dynamic> j) => ProgramConfig(
        id: j['id'] as String,
        title: j['title'] as String,
        feedUrl: j['feedUrl'] as String,
        fallbackImage: j['fallbackImage'] as String?,
      );
}

class LinkConfig {
  LinkConfig({
    required this.id,
    required this.title,
    required this.url,
    this.subtitle,
    this.icon,
    this.inApp = false,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? icon;
  final String url;

  /// Si es `true` se abre dentro de la app (WebView); si no, en el navegador.
  final bool inApp;

  factory LinkConfig.fromJson(Map<String, dynamic> j) => LinkConfig(
        id: j['id'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String?,
        icon: j['icon'] as String?,
        url: j['url'] as String,
        inApp: j['inApp'] as bool? ?? false,
      );
}
