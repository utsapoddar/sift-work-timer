import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/schedule.dart';
import '../services/notifications.dart';
import '../services/audio.dart';
import '../services/milestones.dart';
import 'milestone_screen.dart';

const _accent = Color(0xFFF97316);
const _accentDim = Color(0x1AF97316);
const _bg = Color(0xFF0A0A0A);
const _surface = Color(0xFF141414);
const _border = Color(0xFF252525);


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _totalMinutes = 9 * 60;
  Schedule? _schedule;
  Timer? _ticker;
  int _phaseIndex = 0;
  Duration _remaining = Duration.zero;
  double _phaseProgress = 0.0;
  bool _running = false;
  bool _paused = false;
  DateTime? _pauseStart;
  int _totalPausedMs = 0;
  bool _alarmPlaying = false;
  bool _sessionComplete = false;
  int _lastPhaseIndex = -1;
  String? _ringtonePath;
  StreamSubscription<void>? _alarmCompleteSub;
  late final AnimationController _pulseCtrl;
  int _totalSessions = 0;
  int _streakDays = 0;
  Milestone? _pendingMilestone;

  static const _prefKeyRingtone = 'ringtone_path';
  static const _prefKeySessions = 'total_sessions';
  static const _prefKeyStreakDays = 'streak_days';
  static const _prefKeyStreakDate = 'streak_date';

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _loadPrefs();
    _alarmCompleteSub = onAlarmComplete.listen((_) {
      if (!mounted) return;
      if (_sessionComplete) {
        _stop();
      } else {
        setState(() => _alarmPlaying = false);
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _alarmCompleteSub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════ LOGIC (unchanged) ═══════════════════════════════

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKeyRingtone);
    if (saved != null && File(saved).existsSync()) {
      customRingtonePath = saved;
    } else if (saved != null) {
      await prefs.remove(_prefKeyRingtone);
    }

    var sessions = prefs.getInt(_prefKeySessions) ?? 0;
    var streak = prefs.getInt(_prefKeyStreakDays) ?? 0;
    final lastDateStr = prefs.getString(_prefKeyStreakDate);

    // Silently break streak if more than 1 day has passed since last qualifying session
    if (lastDateStr != null && streak > 0) {
      final lastDay = DateTime.parse(lastDateStr);
      final today = DateTime.now();
      final diff = DateTime(today.year, today.month, today.day)
          .difference(DateTime(lastDay.year, lastDay.month, lastDay.day))
          .inDays;
      if (diff > 1) {
        streak = 0;
        await prefs.setInt(_prefKeyStreakDays, 0);
        await prefs.remove(_prefKeyStreakDate);
      }
    }

    setState(() {
      _ringtonePath = saved != null && File(saved).existsSync() ? saved : null;
      _totalSessions = sessions;
      _streakDays = streak;
    });
  }

  Future<void> _saveRingtone(String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null) {
      await prefs.remove(_prefKeyRingtone);
    } else {
      await prefs.setString(_prefKeyRingtone, path);
    }
    setState(() => _ringtonePath = path);
    customRingtonePath = path;
  }

  Future<void> _showSettings() async {
    final ringtonePathSnapshot = _ringtonePath;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _border)),
        title: const Text('Settings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ringtone',
                style: TextStyle(
                    fontSize: 12,
                    color: _accent,
                    letterSpacing: 1.2)),
            const SizedBox(height: 8),
            Text(
              ringtonePathSnapshot != null
                  ? ringtonePathSnapshot.split('/').last
                  : 'Default alarm tone',
              style:
                  const TextStyle(color: Color(0xFF888888), fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _glassBtn(
                  label: 'Browse…',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.audio,
                      allowMultiple: false,
                    );
                    if (result != null &&
                        result.files.single.path != null) {
                      await _saveRingtone(result.files.single.path);
                      if (mounted) await playAlarm();
                    }
                  },
                ),
                if (ringtonePathSnapshot != null) ...[
                  const SizedBox(width: 8),
                  _glassBtn(
                    label: 'Use Default',
                    onTap: () async {
                      await _saveRingtone(null);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    subtle: true,
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Done', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );
  }

  String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _onSessionComplete() async {
    final prefs = await SharedPreferences.getInstance();

    // Always count total sessions
    final newTotal = _totalSessions + 1;
    await prefs.setInt(_prefKeySessions, newTotal);
    if (mounted) setState(() => _totalSessions = newTotal);

    // Only update streak for 8-hour+ sessions
    if (_totalMinutes >= 480) {
      final oldStreak = _streakDays;
      final today = DateTime.now();
      final todayStr = _dateStr(today);
      final lastDateStr = prefs.getString(_prefKeyStreakDate);

      int newStreak;
      if (lastDateStr == null) {
        newStreak = 1;
      } else if (lastDateStr == todayStr) {
        return; // already counted today
      } else {
        final lastDay = DateTime.parse(lastDateStr);
        final diff = DateTime(today.year, today.month, today.day)
            .difference(
                DateTime(lastDay.year, lastDay.month, lastDay.day))
            .inDays;
        newStreak = diff == 1 ? _streakDays + 1 : 1;
      }

      await prefs.setInt(_prefKeyStreakDays, newStreak);
      await prefs.setString(_prefKeyStreakDate, todayStr);

      // Detect newly crossed milestone
      final newMilestone = detectNewMilestone(oldStreak, newStreak);
      if (mounted) {
        setState(() {
          _streakDays = newStreak;
          if (newMilestone != null) _pendingMilestone = newMilestone;
        });
      }
    }
  }

  void _start() async {
    await requestPermissions();
    final now = DateTime.now();
    final schedule = Schedule.create(now, _totalMinutes);
    await scheduleAll(schedule);
    setState(() {
      _schedule = schedule;
      _running = true;
      _lastPhaseIndex = -1;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _tick();
  }

  Future<void> _triggerAlarm() async {
    setState(() => _alarmPlaying = true);
    await playAlarm();
  }

  Future<void> _stopAlarm() async {
    await stopAlarm();
    if (_sessionComplete) {
      _stop();
    } else {
      setState(() => _alarmPlaying = false);
    }
  }

  void _stop() async {
    // Capture before reset
    final wasComplete = _sessionComplete;
    final pending = _pendingMilestone;
    final streakSnapshot = _streakDays;

    _ticker?.cancel();
    _ticker = null;
    await cancelAll();
    await stopAlarm();
    setState(() {
      _schedule = null;
      _running = false;
      _paused = false;
      _pauseStart = null;
      _totalPausedMs = 0;
      _alarmPlaying = false;
      _sessionComplete = false;
      _pendingMilestone = null;
      _phaseIndex = 0;
      _remaining = Duration.zero;
      _phaseProgress = 0.0;
    });

    // Navigate to milestone celebration if a new milestone was just crossed
    if (wasComplete && pending != null && mounted) {
      final next = getNextMilestone(streakSnapshot);
      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => MilestoneScreen(
            milestone: pending,
            streakDays: streakSnapshot,
            nextMilestone: next,
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  void _pauseSession() {
    _ticker?.cancel();
    _ticker = null;
    cancelAll();
    setState(() {
      _paused = true;
      _pauseStart = DateTime.now();
    });
  }

  void _resumeSession() {
    final start = _pauseStart;
    if (start != null) {
      _totalPausedMs += DateTime.now().difference(start).inMilliseconds;
    }
    final schedule = _schedule;
    if (schedule != null) scheduleAll(schedule, offsetMs: _totalPausedMs);
    setState(() {
      _paused = false;
      _pauseStart = null;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _tick();
  }

  void _tick() {
    final schedule = _schedule;
    if (schedule == null) return;

    final now =
        DateTime.now().subtract(Duration(milliseconds: _totalPausedMs));
    final idx = schedule.currentPhaseIndex(now);

    if (idx >= schedule.phases.length) {
      _ticker?.cancel();
      _ticker = null;
      cancelAll();
      _onSessionComplete(); // fire-and-forget, updates sessions + streak
      setState(() => _sessionComplete = true);
      _triggerAlarm();
      return;
    }

    final phase = schedule.phases[idx];
    final remaining = phase.remaining(now);
    final progress = phase.progress(now);

    if (idx != _lastPhaseIndex && _lastPhaseIndex != -1) {
      _triggerAlarm();
    }
    _lastPhaseIndex = idx;

    setState(() {
      _phaseIndex = idx;
      _remaining = remaining;
      _phaseProgress = progress;
    });
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  Color _phaseColor(Phase phase) {
    if (phase.name == 'Lunch Break') return Colors.amber;
    if (phase.isBreak) return const Color(0xFF34D399);
    return _accent;
  }

  String _formatSessionLabel(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  Future<void> _showDurationPicker() async {
    final presets = {
      7 * 60: '7 hours',
      8 * 60: '8 hours',
      9 * 60: '9 hours',
      10 * 60: '10 hours',
    };

    int selected = _totalMinutes;
    bool isCustom = !presets.containsKey(_totalMinutes);
    final hoursCtrl =
        TextEditingController(text: isCustom ? '${_totalMinutes ~/ 60}' : '');
    final minsCtrl =
        TextEditingController(text: isCustom ? '${_totalMinutes % 60}' : '');

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _border)),
          title: const Text('Set Work Hours',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...presets.entries.map((e) => RadioListTile<int>(
                      value: e.key,
                      groupValue: isCustom ? -1 : selected,
                      activeColor: _accent,
                      title: Row(
                        children: [
                          Text(e.value,
                              style: const TextStyle(color: Colors.white)),
                          if (e.key == 9 * 60) ...[
                            const SizedBox(width: 8),
                            const Text('recommended',
                                style: TextStyle(
                                    fontSize: 11, color: _accent)),
                          ],
                        ],
                      ),
                      onChanged: (v) => setLocal(() {
                        selected = v!;
                        isCustom = false;
                      }),
                    )),
                RadioListTile<int>(
                  value: -1,
                  groupValue: isCustom ? -1 : selected,
                  activeColor: _accent,
                  title: const Text('Custom Duration',
                      style: TextStyle(color: Colors.white)),
                  onChanged: (_) => setLocal(() => isCustom = true),
                ),
                if (isCustom)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: hoursCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Hours',
                              labelStyle: TextStyle(color: Color(0xFF888888)),
                              border: OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: _border)),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: minsCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Minutes',
                              labelStyle: TextStyle(color: Color(0xFF888888)),
                              border: OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: _border)),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF888888))),
            ),
            TextButton(
              onPressed: () {
                int result;
                if (isCustom) {
                  final h = int.tryParse(hoursCtrl.text) ?? 0;
                  final m = int.tryParse(minsCtrl.text) ?? 0;
                  result = (h * 60 + m).clamp(1, 24 * 60);
                } else {
                  result = selected;
                }
                setState(() => _totalMinutes = result);
                Navigator.pop(ctx);
              },
              child: const Text('Set', style: TextStyle(color: _accent)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════ BUILD ═══════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 22),
              _buildPresets(),
              const SizedBox(height: 30),
              _buildTimerRing(),
              const SizedBox(height: 30),
              _buildControls(),
              const SizedBox(height: 22),
              _buildStats(),
              const SizedBox(height: 18),
              _buildPhaseDots(),
              if (!_running) ...[
                const SizedBox(height: 22),
                _buildMotivationCard(),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Text(
          'Sift',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
        const Spacer(),
        if (_running)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _accentDim,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accent.withOpacity(0.3)),
            ),
            child: Text(
              _paused
                  ? '${_formatSessionLabel(_totalMinutes)}  ·  Paused'
                  : _formatSessionLabel(_totalMinutes),
              style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: _accent,
                  fontWeight: FontWeight.w500),
            ),
          ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _showSettings,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
              border: Border.all(
                  color: Colors.white.withOpacity(0.09), width: 1.5),
            ),
            child: const Icon(Icons.settings_outlined,
                size: 17, color: Color(0xFF777777)),
          ),
        ),
      ],
    );
  }

  Widget _buildPresets() {
    final presets = {
      7 * 60: '7h',
      8 * 60: '8h',
      9 * 60: '9h ★',
      10 * 60: '10h',
    };
    final isCustom = !presets.containsKey(_totalMinutes);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...presets.entries.map((e) {
            final selected = !isCustom && _totalMinutes == e.key;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _presetChip(
                label: e.value,
                selected: selected,
                onTap: _running ? null : () => setState(() => _totalMinutes = e.key),
              ),
            );
          }),
          _presetChip(
            label: isCustom ? '${_formatSessionLabel(_totalMinutes)} ✎' : 'Custom',
            selected: isCustom,
            onTap: _running ? null : _showDurationPicker,
          ),
        ],
      ),
    );
  }

  Widget _presetChip({
    required String label,
    required bool selected,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _accentDim : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? _accent
                : Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color:
                selected ? _accent : const Color(0xFF777777),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerRing() {
    final schedule = _schedule;
    final phase = (schedule != null && _running && !_sessionComplete)
        ? schedule.phases[_phaseIndex].phase
        : null;
    final color = phase != null ? _phaseColor(phase) : _accent;
    final progress =
        _sessionComplete ? 1.0 : (_running ? _phaseProgress : 0.0);
    final label = _sessionComplete
        ? 'Session Complete'
        : (phase?.name.toUpperCase() ?? 'READY');
    final timeStr = (_running && !_sessionComplete)
        ? _formatDuration(_remaining)
        : '--:--';

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final glowOpacity = 0.05 + _pulseCtrl.value * 0.07;
        return Center(
          child: SizedBox(
            width: 250,
            height: 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Ambient glow
                Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(glowOpacity),
                        blurRadius: 70,
                        spreadRadius: 20,
                      )
                    ],
                  ),
                ),
                // Ring
                CustomPaint(
                  size: const Size(250, 250),
                  painter: _RingPainter(progress: progress, accent: color),
                ),
                // Center text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeStr,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                        color: Colors.white,
                        letterSpacing: -2,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF555555),
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls() {
    final showPauseResume = _running && !_sessionComplete;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showPauseResume) ...[
          _circleBtn(icon: Icons.stop_rounded, onTap: _stop, size: 52),
          const SizedBox(width: 18),
        ],
        _circleBtn(
          icon: (_running && !_paused && !_sessionComplete)
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          onTap: _sessionComplete
              ? null
              : (_running
                  ? (_paused ? _resumeSession : _pauseSession)
                  : _start),
          size: 70,
          isAccent: true,
        ),
        if (_alarmPlaying) ...[
          const SizedBox(width: 18),
          _circleBtn(
            icon: Icons.volume_off_rounded,
            onTap: _stopAlarm,
            size: 52,
            glowColor: Colors.red,
          ),
        ],
      ],
    );
  }

  Widget _circleBtn({
    required IconData icon,
    VoidCallback? onTap,
    double size = 52,
    bool isAccent = false,
    Color? glowColor,
  }) {
    final bg = isAccent
        ? _accent
        : (glowColor ?? Colors.white.withOpacity(0.04));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: isAccent
              ? null
              : Border.all(
                  color: Colors.white.withOpacity(0.09), width: 1.5),
          boxShadow: isAccent
              ? [
                  BoxShadow(
                      color: _accent.withOpacity(0.45),
                      blurRadius: 28,
                      spreadRadius: 0),
                  BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 14,
                      offset: const Offset(0, 6)),
                ]
              : glowColor != null
                  ? [
                      BoxShadow(
                          color: glowColor.withOpacity(0.4),
                          blurRadius: 18)
                    ]
                  : null,
        ),
        child: Icon(
          icon,
          size: size * 0.4,
          color: isAccent
              ? Colors.black
              : glowColor != null
                  ? Colors.white
                  : const Color(0xFF777777),
        ),
      ),
    );
  }

  Widget _buildStats() {
    final schedule = _schedule;

    if (!_running) {
      // Idle: show lifetime stats
      final streakLabel = _streakDays > 0 ? '$_streakDays 🔥' : '--';
      return Row(
        children: [
          _statBox('Sessions', '$_totalSessions'),
          const SizedBox(width: 3),
          _statBox('Streak', streakLabel),
          const SizedBox(width: 3),
          _statBox('Duration', _formatSessionLabel(_totalMinutes)),
        ],
      );
    }

    // Running: show live progress stats
    String phasesVal = '$_phaseIndex / ${schedule!.phases.length}';
    String typeVal = _sessionComplete
        ? 'Done'
        : schedule.phases[_phaseIndex].phase.name.split(' ').first;
    String totalVal = '0m';
    if (!_sessionComplete) {
      final now = DateTime.now().subtract(Duration(milliseconds: _totalPausedMs));
      final left = schedule.sessionEnd.difference(now);
      if (!left.isNegative) {
        final h = left.inHours;
        final m = left.inMinutes.remainder(60);
        totalVal = h > 0 ? '${h}h ${m}m' : '${m}m';
      }
    }

    return Row(
      children: [
        _statBox('Phases', phasesVal),
        const SizedBox(width: 3),
        _statBox('Current', typeVal),
        const SizedBox(width: 3),
        _statBox('Remaining', totalVal),
      ],
    );
  }

  Widget _statBox(String label, String value) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.025),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border, width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 9,
                letterSpacing: 1.2,
                color: const Color(0xFF444444),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseDots() {
    final schedule = _schedule;
    final count = schedule?.phases.length ?? 7;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final isPast = _running && i < _phaseIndex;
        final isCurrent =
            _running && !_sessionComplete && i == _phaseIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isCurrent ? 9 : 7,
            height: isCurrent ? 9 : 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isPast || isCurrent || _sessionComplete)
                  ? _accent
                  : Colors.white.withOpacity(0.12),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                          color: _accent.withOpacity(0.65),
                          blurRadius: 8)
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMotivationCard() {
    // Find current (highest unlocked) and next milestone
    Milestone? current;
    Milestone? next;
    for (int i = 0; i < milestones.length; i++) {
      if (_streakDays >= milestones[i].day) {
        current = milestones[i];
      } else if (next == null) {
        next = milestones[i];
      }
    }

    if (_streakDays == 0 || current == null) {
      // No streak yet
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.025),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            const Text('🌱', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              'Start your streak',
              style: GoogleFonts.outfit(
                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete a full session to begin your streak.',
              style: GoogleFonts.outfit(
                  fontSize: 12, color: const Color(0xFF555555)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Progress to next milestone
    double progress = 1.0;
    String nextLabel = 'Max reached';
    if (next != null) {
      final span = next.day - current.day;
      final done = _streakDays - current.day;
      progress = span > 0 ? (done / span).clamp(0.0, 1.0) : 1.0;
      nextLabel = 'Next: Day ${next.day} — ${next.title}';
    }

    final c = current.color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Badge
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.withOpacity(0.12),
                  border: Border.all(color: c.withOpacity(0.35)),
                ),
                child: Center(
                  child: Text(current.icon,
                      style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Day ${current.day} — ${current.title}',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'You are here',
                            style: GoogleFonts.outfit(
                                fontSize: 9,
                                color: c,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      current.sub,
                      style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: const Color(0xFF888888),
                          height: 1.4),
                    ),
                  ],
                ),
              ),
              // Streak + rarity
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$_streakDays 🔥',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 18, fontWeight: FontWeight.w500, color: c),
                  ),
                  Text(
                    current.rarity,
                    style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: const Color(0xFF555555)),
                  ),
                  Text(
                    'still going',
                    style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: const Color(0xFF444444)),
                  ),
                ],
              ),
            ],
          ),
          // Science blurb
          const SizedBox(height: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: c.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.withOpacity(0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🧪 ',
                    style: TextStyle(fontSize: 12)),
                Expanded(
                  child: Text(
                    current.science,
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: const Color(0xFF777777),
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          // Progress bar to next milestone
          if (next != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: c.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation(c),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              nextLabel,
              style: GoogleFonts.outfit(
                  fontSize: 10, color: const Color(0xFF555555)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _glassBtn({
    required String label,
    required VoidCallback onTap,
    bool subtle = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: subtle
              ? Colors.transparent
              : _accentDim,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: subtle
                  ? Colors.white.withOpacity(0.08)
                  : _accent.withOpacity(0.4)),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: subtle ? const Color(0xFF777777) : _accent,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════ RING PAINTER ═══════════════════════════════

class _RingPainter extends CustomPainter {
  final double progress;
  final Color accent;

  const _RingPainter({required this.progress, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 18;

    // Outer dashed deco ring
    _drawDashedCircle(
      canvas,
      center,
      radius + 13,
      Paint()
        ..color = accent.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6,
      3.0,
      10.0,
    );

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withOpacity(0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );

    if (progress <= 0) return;

    final sweep = 2 * math.pi * progress;

    // Glow layer
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = accent.withOpacity(0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // Main arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );

    // Head dot
    final headAngle = -math.pi / 2 + sweep;
    final dx = center.dx + radius * math.cos(headAngle);
    final dy = center.dy + radius * math.sin(headAngle);
    canvas.drawCircle(
      Offset(dx, dy),
      6,
      Paint()
        ..color = accent.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(Offset(dx, dy), 5, Paint()..color = accent);
  }

  void _drawDashedCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Paint paint,
    double dashLen,
    double gapLen,
  ) {
    final circumference = 2 * math.pi * radius;
    final count = (circumference / (dashLen + gapLen)).floor();
    for (int i = 0; i < count; i++) {
      final start = (i * (dashLen + gapLen)) / radius - math.pi / 2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dashLen / radius,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.accent != accent;
}
