import 'package:flutter_test/flutter_test.dart';
import 'package:work_timer/services/durable_stats.dart';

void main() {
  group('resolveStats', () {
    test('uses prefs when keychain is absent', () {
      final prefs = const PrefsStats(
        streakDays: 7,
        streakDate: '2026-06-30',
        totalSessions: 12,
      );

      final resolved = resolveStats(prefs, null);

      expect(resolved.stats, prefs);
      expect(resolved.source, StatsSource.prefs);
    });

    test('restores from keychain when prefs are reset behind', () {
      final prefs = const PrefsStats(
        streakDays: 0,
        streakDate: null,
        totalSessions: 0,
      );
      final keychain = const KeychainStats(
        streakDays: 14,
        streakDate: '2026-06-30',
        totalSessions: 50,
      );

      final resolved = resolveStats(prefs, keychain);

      expect(resolved.stats.streakDays, 14);
      expect(resolved.stats.streakDate, '2026-06-30');
      expect(resolved.stats.totalSessions, 50);
      expect(resolved.source, StatsSource.keychain);
    });

    test('keeps the same values when prefs and keychain totals are tied', () {
      final prefs = const PrefsStats(
        streakDays: 4,
        streakDate: '2026-06-30',
        totalSessions: 50,
      );
      final keychain = const KeychainStats(
        streakDays: 4,
        streakDate: '2026-06-30',
        totalSessions: 50,
      );

      final resolved = resolveStats(prefs, keychain);

      expect(resolved.stats, prefs);
      expect(resolved.source, StatsSource.keychain);
    });

    test('keeps prefs when prefs are ahead of keychain', () {
      final prefs = const PrefsStats(
        streakDays: 8,
        streakDate: '2026-07-01',
        totalSessions: 60,
      );
      final keychain = const KeychainStats(
        streakDays: 7,
        streakDate: '2026-06-30',
        totalSessions: 50,
      );

      final resolved = resolveStats(prefs, keychain);

      expect(resolved.stats, prefs);
      expect(resolved.source, StatsSource.prefs);
    });
  });
}
