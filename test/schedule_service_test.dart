import 'dart:io';

import 'package:euskadigital/config/app_config.dart';
import 'package:euskadigital/services/schedule_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final programs = [
    ProgramConfig(id: 'gaming-room', title: 'Gaming Room', feedUrl: ''),
    ProgramConfig(id: 'enredando', title: 'EnRedAndo', feedUrl: ''),
    ProgramConfig(id: 'ecdqemsd', title: 'En Caso de que El Mundo se Desintegre', feedUrl: ''),
  ];
  final entries = ScheduleService.parse(File('test/fixtures/parrilla.json').readAsStringSync(), programs);

  test('lee la parrilla del emisor y reconoce nuestros programas', () {
    final gaming = entries.firstWhere((e) => e.name == 'Gaming Room');
    expect(gaming.start, DateTime(2026, 11, 23, 19));
    expect(gaming.end, DateTime(2026, 11, 23, 21));
    expect(gaming.program?.id, 'gaming-room');
    expect(entries.firstWhere((e) => e.name.startsWith('En Caso')).program?.id, 'ecdqemsd');
    expect(entries.firstWhere((e) => e.name == 'EnRedAndo (Repetición)').program?.id, 'enredando');
    expect(entries.firstWhere((e) => e.name == 'Matinales de EuskaDigital').program, isNull);
  });

  test('une los bloques seguidos con el mismo nombre', () {
    final night = entries.where((e) => e.name == 'Tracks Night' && e.start.day == 28).toList();
    expect(night, hasLength(1));
    expect(night.single.start, DateTime(2026, 11, 28, 22));
    expect(night.single.end, DateTime(2026, 11, 29, 2));
  });

  test('como la web: hoy y 3 días más, sin lo ya terminado', () {
    final now = DateTime(2026, 11, 23, 20, 30); // lunes, en mitad de Gaming Room
    final days = ScheduleService.groupUpcoming(entries, now);
    expect(days.keys, [
      DateTime(2026, 11, 23),
      DateTime(2026, 11, 24),
      DateTime(2026, 11, 25),
      DateTime(2026, 11, 26),
    ]);
    final today = days[DateTime(2026, 11, 23)]!.map((e) => e.name).toList();
    expect(today, ['Gaming Room', 'En Caso de que el Mundo Se Desintegre']); // los Matinales ya acabaron
    expect(days[DateTime(2026, 11, 23)]!.first.isOnAirAt(now), isTrue);
  });
}
