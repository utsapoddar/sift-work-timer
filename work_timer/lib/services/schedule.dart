class Phase {
  final String name;
  final String description;
  final Duration duration;
  final bool isBreak;

  const Phase({
    required this.name,
    required this.description,
    required this.duration,
    this.isBreak = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'durationMs': duration.inMilliseconds,
    'isBreak': isBreak,
  };

  factory Phase.fromJson(Map<String, dynamic> json) {
    return Phase(
      name: json['name'] as String,
      description: json['description'] as String,
      duration: Duration(milliseconds: (json['durationMs'] as num).toInt()),
      isBreak: json['isBreak'] as bool? ?? false,
    );
  }
}

class ScheduledPhase {
  final Phase phase;
  final DateTime startTime;
  final DateTime endTime;
  final int index;

  const ScheduledPhase({
    required this.phase,
    required this.startTime,
    required this.endTime,
    required this.index,
  });

  Duration remaining(DateTime now) {
    final r = endTime.difference(now);
    return r.isNegative ? Duration.zero : r;
  }

  double progress(DateTime now) {
    final elapsed = now.difference(startTime).inSeconds;
    final total = phase.duration.inSeconds;
    if (total == 0) return 1.0;
    return (elapsed / total).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
    'phase': phase.toJson(),
    'startTimeMs': startTime.millisecondsSinceEpoch,
    'endTimeMs': endTime.millisecondsSinceEpoch,
    'index': index,
  };

  factory ScheduledPhase.fromJson(Map<String, dynamic> json) {
    return ScheduledPhase(
      phase: Phase.fromJson(json['phase'] as Map<String, dynamic>),
      startTime: DateTime.fromMillisecondsSinceEpoch(
        (json['startTimeMs'] as num).toInt(),
      ),
      endTime: DateTime.fromMillisecondsSinceEpoch(
        (json['endTimeMs'] as num).toInt(),
      ),
      index: (json['index'] as num).toInt(),
    );
  }
}

class Schedule {
  final DateTime sessionStart;
  final int totalMinutes;
  final List<ScheduledPhase> phases;

  const Schedule({
    required this.sessionStart,
    required this.totalMinutes,
    required this.phases,
  });

  Map<String, dynamic> toJson() => {
    'sessionStartMs': sessionStart.millisecondsSinceEpoch,
    'totalMinutes': totalMinutes,
    'phases': phases.map((p) => p.toJson()).toList(),
  };

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      sessionStart: DateTime.fromMillisecondsSinceEpoch(
        (json['sessionStartMs'] as num).toInt(),
      ),
      totalMinutes: (json['totalMinutes'] as num).toInt(),
      phases: (json['phases'] as List<dynamic>)
          .map((p) => ScheduledPhase.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  static Schedule create(DateTime startTime, int totalMinutes) {
    // Scale all segments proportionally from the 9h (540 min) baseline:
    //   work block  = 112.5 / 540  =  5/24  of total
    //   short break =  15.0 / 540  =  1/36  of total
    //   lunch break =  60.0 / 540  =  1/9   of total
    final total = totalMinutes * 60; // work in seconds for precision
    Duration scaled(double ratio) => Duration(seconds: (total * ratio).round());

    final workLong = scaled(2 / 9); // 2h in a 9h session
    final shortBreak = scaled(1 / 36); // 15min
    final workShort = scaled(7 / 36); // 1h45m
    final lunchBreak = scaled(1 / 9); // 1h

    final phaseDefs = [
      Phase(name: 'Work', description: 'Focus block', duration: workLong),
      Phase(
        name: 'Short Break',
        description: 'Take a short break',
        duration: shortBreak,
        isBreak: true,
      ),
      Phase(name: 'Work', description: 'Focus block', duration: workShort),
      Phase(
        name: 'Lunch Break',
        description: 'Enjoy your lunch break',
        duration: lunchBreak,
        isBreak: true,
      ),
      Phase(name: 'Work', description: 'Focus block', duration: workLong),
      Phase(
        name: 'Short Break',
        description: 'Take a short break',
        duration: shortBreak,
        isBreak: true,
      ),
      Phase(name: 'Work', description: 'Focus block', duration: workShort),
    ];

    final phases = <ScheduledPhase>[];
    var cursor = startTime;

    for (int i = 0; i < phaseDefs.length; i++) {
      final def = phaseDefs[i];
      final end = cursor.add(def.duration);
      phases.add(
        ScheduledPhase(phase: def, startTime: cursor, endTime: end, index: i),
      );
      cursor = end;
    }

    return Schedule(
      sessionStart: startTime,
      totalMinutes: totalMinutes,
      phases: phases,
    );
  }

  DateTime get sessionEnd => phases.last.endTime;

  /// Returns the index of the current active phase, or phases.length if done.
  int currentPhaseIndex(DateTime now) {
    for (int i = 0; i < phases.length; i++) {
      if (now.isBefore(phases[i].endTime)) return i;
    }
    return phases.length;
  }
}
