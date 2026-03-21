import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

const _accent = Color(0xFFF97316);
const _bg = Color(0xFF0A0A0A);

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 3),

              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _accent.withOpacity(0.1),
                  border: Border.all(color: _accent.withOpacity(0.3), width: 1.5),
                ),
                child: const Center(
                  child: Text('🔥', style: TextStyle(fontSize: 28)),
                ),
              ),

              const SizedBox(height: 32),

              // Title
              Text(
                'Ready to find out\nhow far you can go?',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),

              const SizedBox(height: 20),

              // Primary body
              Text(
                'Most people plan to work hard.\nFew actually track it — day after day, without excuses.',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  color: const Color(0xFF888888),
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 14),

              // Secondary body
              Text(
                'This app measures one thing: consecutive days of real, focused work. Your streak is yours to build — or break. No tricks. No shortcuts. Just you, showing up.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: const Color(0xFF4A4A4A),
                  height: 1.65,
                ),
              ),

              const Spacer(flex: 4),

              // CTA
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('onboarded', true);
                    if (context.mounted) {
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => const HomeScreen(),
                          transitionsBuilder: (_, anim, __, child) =>
                              FadeTransition(opacity: anim, child: child),
                          transitionDuration:
                              const Duration(milliseconds: 500),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'I\'m committed',
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              Center(
                child: Text(
                  'Every great streak started exactly here.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: const Color(0xFF333333),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
