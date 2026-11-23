import 'package:euskadigital/config/app_config.dart';
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

  test('reconoce cuándo suena uno de nuestros programas', () {
    final programs = [
      ProgramConfig(id: 'enredando', title: 'EnRedAndo', feedUrl: ''),
      ProgramConfig(id: 'gaming-room', title: 'Gaming Room', feedUrl: ''),
      ProgramConfig(id: 'sarean-zehar', title: 'Sarean Zehar', feedUrl: ''),
    ];
    expect(PlayerService.matchProgram('EnRedAndo 838 - La informática que se escucha', programs)?.id, 'enredando');
    expect(PlayerService.matchProgram('GAMING ROOM #135', programs)?.id, 'gaming-room');
    expect(PlayerService.matchProgram('Sarean-Zehar: especial', programs)?.id, 'sarean-zehar');
    expect(PlayerService.matchProgram('Drunksouls - No more fighting', programs), isNull);
  });
}
