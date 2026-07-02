DateTime scheduleNow({
  required DateTime wallNow,
  required int totalPausedMs,
  required bool isPaused,
  required DateTime? pauseStart,
}) {
  var pausedMs = totalPausedMs;
  if (isPaused && pauseStart != null) {
    final activePauseMs = wallNow.difference(pauseStart).inMilliseconds;
    pausedMs += activePauseMs < 0 ? 0 : activePauseMs;
  }
  return wallNow.subtract(Duration(milliseconds: pausedMs));
}
