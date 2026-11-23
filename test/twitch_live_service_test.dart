import 'package:euskadigital/services/twitch_live_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TwitchLiveService service(http.Response Function(http.Request) respond) =>
      TwitchLiveService('euskadigital', client: MockClient((r) async => respond(r)), autoStart: false);

  test('en directo cuando la vista previa devuelve una imagen', () async {
    final s = service((_) => http.Response.bytes([0xFF, 0xD8], 200, headers: {'content-type': 'image/jpeg'}));
    await s.check();
    expect(s.isLive, isTrue);
  });

  test('desconectado cuando Twitch redirige a la imagen genérica', () async {
    final s = service((_) => http.Response('', 302, headers: {
          'location': 'https://static-cdn.jtvnw.net/ttv-static/404_preview-80x45.jpg',
          'content-type': 'text/html',
        }));
    await s.check();
    expect(s.isLive, isFalse);
  });

  test('sin conexión mantiene el último estado', () async {
    var fail = false;
    final s = TwitchLiveService('euskadigital',
        autoStart: false,
        client: MockClient((_) async {
          if (fail) throw http.ClientException('sin red');
          return http.Response.bytes([1], 200, headers: {'content-type': 'image/jpeg'});
        }));
    await s.check();
    fail = true;
    await s.check();
    expect(s.isLive, isTrue);
  });
}
