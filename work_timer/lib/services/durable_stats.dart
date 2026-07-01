import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PrefsStats {
  const PrefsStats({
    required this.streakDays,
    required this.streakDate,
    required this.totalSessions,
  });

  final int streakDays;
  final String? streakDate;
  final int totalSessions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrefsStats &&
          streakDays == other.streakDays &&
          streakDate == other.streakDate &&
          totalSessions == other.totalSessions;

  @override
  int get hashCode => Object.hash(streakDays, streakDate, totalSessions);
}

class KeychainStats {
  const KeychainStats({
    required this.streakDays,
    required this.streakDate,
    required this.totalSessions,
  });

  final int? streakDays;
  final String? streakDate;
  final int? totalSessions;
}

enum StatsSource { prefs, keychain }

class ResolvedStats {
  const ResolvedStats({required this.stats, required this.source});

  final PrefsStats stats;
  final StatsSource source;
}

ResolvedStats resolveStats(PrefsStats prefs, KeychainStats? keychain) {
  final keychainTotal = keychain?.totalSessions;
  final keychainStreak = keychain?.streakDays;
  if (keychainTotal != null &&
      keychainStreak != null &&
      keychainTotal >= prefs.totalSessions) {
    return ResolvedStats(
      stats: PrefsStats(
        streakDays: keychainStreak,
        streakDate: keychain!.streakDate,
        totalSessions: keychainTotal,
      ),
      source: StatsSource.keychain,
    );
  }

  return ResolvedStats(stats: prefs, source: StatsSource.prefs);
}

class DurableStats {
  DurableStats({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _keySessions = 'total_sessions';
  static const _keyStreakDays = 'streak_days';
  static const _keyStreakDate = 'streak_date';

  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
    synchronizable: false,
  );

  Future<void> writeStats({
    required int streakDays,
    required String? streakDate,
    required int totalSessions,
  }) async {
    await _storage.write(
      key: _keySessions,
      value: totalSessions.toString(),
      iOptions: _iosOptions,
    );
    await _storage.write(
      key: _keyStreakDays,
      value: streakDays.toString(),
      iOptions: _iosOptions,
    );
    if (streakDate == null) {
      await _storage.delete(key: _keyStreakDate, iOptions: _iosOptions);
    } else {
      await _storage.write(
        key: _keyStreakDate,
        value: streakDate,
        iOptions: _iosOptions,
      );
    }
  }

  Future<KeychainStats?> readStats() async {
    final totalSessions = int.tryParse(
      await _storage.read(key: _keySessions, iOptions: _iosOptions) ?? '',
    );
    final streakDays = int.tryParse(
      await _storage.read(key: _keyStreakDays, iOptions: _iosOptions) ?? '',
    );
    final streakDate = await _storage.read(
      key: _keyStreakDate,
      iOptions: _iosOptions,
    );

    if (totalSessions == null && streakDays == null && streakDate == null) {
      return null;
    }

    return KeychainStats(
      streakDays: streakDays,
      streakDate: streakDate,
      totalSessions: totalSessions,
    );
  }
}
