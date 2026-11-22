import 'package:euskadigital/models/episode.dart';
import 'package:euskadigital/services/episode_alerts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Episode ep(String id, DateTime date, {bool audio = true}) => Episode(
      id: id,
      feedId: 'p',
      title: id,
      pubDate: date,
      audioUrl: audio ? 'https://example.com/$id.mp3' : null,
    );

void main() {
  final d1 = DateTime.utc(2026, 1, 1);
  final d2 = DateTime.utc(2026, 1, 8);
  final d3 = DateTime.utc(2026, 1, 15);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('la primera revisión solo guarda la referencia, sin avisar', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(EpisodeAlerts.newEpisodes(prefs, 'p', [ep('a', d1), ep('b', d2)]), isEmpty);
  });

  test('avisa solo de los episodios posteriores, más recientes primero', () async {
    final prefs = await SharedPreferences.getInstance();
    EpisodeAlerts.newEpisodes(prefs, 'p', [ep('a', d1)]);
    final fresh = EpisodeAlerts.newEpisodes(prefs, 'p', [ep('a', d1), ep('b', d2), ep('c', d3)]);
    expect(fresh.map((e) => e.id), ['c', 'b']);
    // Ya avisados: la siguiente revisión no repite.
    expect(EpisodeAlerts.newEpisodes(prefs, 'p', [ep('a', d1), ep('b', d2), ep('c', d3)]), isEmpty);
  });

  test('ignora entradas sin audio', () async {
    final prefs = await SharedPreferences.getInstance();
    EpisodeAlerts.newEpisodes(prefs, 'p', [ep('a', d1)]);
    expect(EpisodeAlerts.newEpisodes(prefs, 'p', [ep('a', d1), ep('post', d3, audio: false)]), isEmpty);
  });

  test('lo visto en la app no se avisa después', () async {
    final prefs = await SharedPreferences.getInstance();
    EpisodeAlerts.newEpisodes(prefs, 'p', [ep('a', d1)]);
    await EpisodeAlerts.rememberSeen(prefs, 'p', [ep('a', d1), ep('b', d2)]);
    expect(EpisodeAlerts.newEpisodes(prefs, 'p', [ep('a', d1), ep('b', d2)]), isEmpty);
  });

  test('un feed que retrocede (episodio borrado) no rebaja la referencia', () async {
    final prefs = await SharedPreferences.getInstance();
    EpisodeAlerts.newEpisodes(prefs, 'p', [ep('a', d1), ep('c', d3)]);
    EpisodeAlerts.newEpisodes(prefs, 'p', [ep('a', d1)]);
    expect(EpisodeAlerts.newEpisodes(prefs, 'p', [ep('a', d1), ep('b', d2)]), isEmpty);
  });
}
