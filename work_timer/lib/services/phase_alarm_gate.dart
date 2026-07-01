class PhaseAlarmGateResolution {
  final int totalPausedMs;
  final int activePhaseIndex;

  const PhaseAlarmGateResolution({
    required this.totalPausedMs,
    required this.activePhaseIndex,
  });
}

PhaseAlarmGateResolution resolvePhaseAlarmGate({
  required int totalPausedMs,
  required DateTime gateStartedAt,
  required DateTime stoppedAt,
  required int pendingPhaseIndex,
}) {
  final gateMs = stoppedAt.difference(gateStartedAt).inMilliseconds;
  return PhaseAlarmGateResolution(
    totalPausedMs: totalPausedMs + (gateMs < 0 ? 0 : gateMs),
    activePhaseIndex: pendingPhaseIndex,
  );
}
