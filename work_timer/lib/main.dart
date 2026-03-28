import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzData;
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzData.initializeTimeZones();
  await initNotifications();
  await requestPermissions();

  final prefs = await SharedPreferences.getInstance();
  final onboarded = prefs.getBool('onboarded') ?? false;

  runApp(WorkTimerApp(showOnboarding: !onboarded));
}

class WorkTimerApp extends StatelessWidget {
  final bool showOnboarding;
  const WorkTimerApp({super.key, this.showOnboarding = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sift',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFF97316),
          brightness: Brightness.dark,
        ).copyWith(
          surface: const Color(0xFF0A0A0A),
          surfaceContainerHighest: const Color(0xFF141414),
        ),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: showOnboarding ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}
