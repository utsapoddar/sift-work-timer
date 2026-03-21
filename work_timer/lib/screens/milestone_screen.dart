import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/milestones.dart';

const _bg = Color(0xFF0A0A0A);
const _border = Color(0xFF252525);

class MilestoneScreen extends StatelessWidget {
  final Milestone milestone;
  final int streakDays;
  final Milestone? nextMilestone;

  const MilestoneScreen({
    super.key,
    required this.milestone,
    required this.streakDays,
    required this.nextMilestone,
  });

  bool get _isLast => nextMilestone == null;

  double get _progressToNext {
    if (nextMilestone == null) return 1.0;
    final span = nextMilestone!.day - milestone.day;
    final done = streakDays - milestone.day;
    return span > 0 ? (done / span).clamp(0.0, 1.0) : 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final c = milestone.color;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: close button
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.08), width: 1),
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: Color(0xFF666666)),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Badge
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.withOpacity(0.1),
                    border: Border.all(color: c.withOpacity(0.35), width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: c.withOpacity(0.2),
                          blurRadius: 40,
                          spreadRadius: 8),
                    ],
                  ),
                  child: Center(
                    child: Text(milestone.icon,
                        style: const TextStyle(fontSize: 40)),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Day label
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Day $streakDays',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 13, fontWeight: FontWeight.w500, color: c),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Milestone title
              Center(
                child: Text(
                  _isLast
                      ? 'You\'ve done it.'
                      : 'Congratulations.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF666666),
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 6),

              Center(
                child: Text(
                  milestone.title,
                  style: GoogleFonts.outfit(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 24),

              // Sub text
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.withOpacity(0.18)),
                ),
                child: Text(
                  _isLast
                      ? 'You have done something most people can only imagine. ${milestone.sub}'
                      : milestone.sub,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.85),
                    height: 1.55,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Science blurb
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.025),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🧪 ', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Text(
                        milestone.science,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF777777),
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── LAST MILESTONE ──
              if (_isLast) ...[
                _divider(c),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A personal note',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: c,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'I built this app hoping someone would reach this. That someone is you.\n\nI would genuinely love to hear what kept you going, what almost stopped you, and how this changed your work.',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                          height: 1.65,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GestureDetector(
                        onTap: () {},
                        child: Text(
                          'utsapoddar@gmail.com',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 13,
                            color: c,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                            decorationColor: c.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _ctaButton(context, c, isLast: true),
              ],

              // ── REGULAR MILESTONE ──
              if (!_isLast) ...[
                _divider(c),
                const SizedBox(height: 18),

                // Next milestone
                Text(
                  'YOUR NEXT CHALLENGE',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: const Color(0xFF444444),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.025),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Text(nextMilestone!.icon,
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Day ${nextMilestone!.day} — ${nextMilestone!.title}',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              nextMilestone!.rarity + ' of people reach this',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: const Color(0xFF555555),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${nextMilestone!.day - streakDays}d',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 14,
                          color: const Color(0xFF444444),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: _progressToNext,
                    minHeight: 4,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    valueColor: AlwaysStoppedAnimation(c),
                  ),
                ),

                const SizedBox(height: 24),

                // Commitment text
                Text(
                  milestone.commitmentText,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.55,
                  ),
                ),

                const SizedBox(height: 28),
                _ctaButton(context, c, isLast: false),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(Color c) => Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Colors.transparent,
            c.withOpacity(0.25),
            Colors.transparent,
          ]),
        ),
      );

  Widget _ctaButton(BuildContext context, Color c, {required bool isLast}) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: () => Navigator.pop(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: isLast ? Colors.white.withOpacity(0.06) : c,
          foregroundColor: isLast ? Colors.white : Colors.black,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: isLast
                  ? BorderSide(color: Colors.white.withOpacity(0.1))
                  : BorderSide.none),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isLast ? 'Thank you' : 'I\'m committed',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            if (!isLast) ...[
              const SizedBox(width: 10),
              const Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
