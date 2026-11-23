import 'package:euskadigital/services/player_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('limpia el título que envía el stream', () {
    expect(PlayerService.cleanTrackTitle('  Drunksouls -  No more fighting '), 'Drunksouls - No more fighting');
    expect(PlayerService.cleanTrackTitle(''), isNull);
    expect(PlayerService.cleanTrackTitle(' - '), isNull);
    expect(PlayerService.cleanTrackTitle(null), isNull);
    expect(PlayerService.cleanTrackTitle('f1f7a5ab-268c-7419-fb0d-f63dda3e1646'), isNull);
  });
}
