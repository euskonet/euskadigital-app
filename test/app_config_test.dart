import 'package:euskadigital/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final live = LiveConfig.fromJson({
    'title': 'Directo',
    'subtitle': 'Radio',
    'streams': [
      {'id': 'a', 'label': 'A', 'url': 'http://a', 'quality': 'high'},
      {'id': 'b', 'label': 'B', 'url': 'https://b', 'quality': 'high'},
      {'id': 'c', 'label': 'C', 'url': 'https://c', 'quality': 'low'},
    ],
  });

  test('calidad alta: los dos de alta en orden y el de baja como último recurso', () {
    expect(live.streamsFor(LiveQuality.high).map((s) => s.id), ['a', 'b', 'c']);
  });

  test('calidad baja: primero el de baja calidad', () {
    expect(live.streamsFor(LiveQuality.low).map((s) => s.id), ['c', 'a', 'b']);
  });

  test('el selector solo aparece si hay streams de las dos calidades', () {
    expect(live.hasQualityChoice, isTrue);
    final soloAlta = LiveConfig.fromJson({
      'title': 'D',
      'subtitle': 'R',
      'streams': [
        {'id': 'a', 'label': 'A', 'url': 'http://a'},
      ],
    });
    expect(soloAlta.hasQualityChoice, isFalse);
  });

  test('la configuración de la app tiene selector de calidad', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final config = await AppConfig.load();
    expect(config.live.hasQualityChoice, isTrue);
  });
}
