import 'package:flutter_test/flutter_test.dart';
import 'package:wami/core/utils/formatters.dart';

void main() {
  const nbsp = ' ';

  group('Fmt.fcfa', () {
    test('groupe les milliers avec une espace insécable', () {
      expect(Fmt.fcfa(12500), '12${nbsp}500${nbsp}F');
      expect(Fmt.fcfa(800), '800${nbsp}F');
      expect(Fmt.fcfa(1250000), '1${nbsp}250${nbsp}000${nbsp}F');
    });

    test('affiche le signe', () {
      expect(Fmt.fcfa(-2500), '−${nbsp}2${nbsp}500${nbsp}F');
      expect(Fmt.fcfa(10000, signed: true), '+${nbsp}10${nbsp}000${nbsp}F');
    });
  });

  test('Fmt.duration', () {
    expect(Fmt.duration(390), '6${nbsp}h${nbsp}30');
    expect(Fmt.duration(45), '45${nbsp}min');
  });

  test('Fmt.clock', () {
    expect(Fmt.clock(125), '2:05');
  });

  test('Fmt.initials', () {
    expect(Fmt.initials('Gilexe AGBODJOGBE'), 'GA');
    expect(Fmt.initials('wami'), 'W');
  });

  test('Fmt.relativeDay', () {
    final now = DateTime(2026, 10, 24, 9);
    expect(Fmt.relativeDay(DateTime(2026, 10, 24, 18), now: now), 'Aujourd’hui');
    expect(Fmt.relativeDay(DateTime(2026, 10, 25), now: now), 'Demain');
  });
}
