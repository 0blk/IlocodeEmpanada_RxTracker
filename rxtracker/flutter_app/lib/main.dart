import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/foundation.dart';

import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/medicine_provider.dart';
import 'screens/home_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/add_medicine_screen.dart';
import 'screens/history_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/medicines_screen.dart';
import 'screens/schedule_screen.dart';
import 'widgets/starfield_background.dart';
import 'widgets/phone_frame.dart';
import 'widgets/hover_scale.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  if (!kIsWeb) {
    await NotificationService.instance.init();
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        ChangeNotifierProxyProvider<ApiService, MedicineProvider>(
          create: (ctx) => MedicineProvider(ctx.read<ApiService>()),
          update: (_, api, prev) => prev ?? MedicineProvider(api),
        ),
      ],
      child: const RxTrackerApp(),
    ),
  );
}

class RxTrackerApp extends StatelessWidget {
  const RxTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RxTracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Modern Indigo
          primary: const Color(0xFF6366F1),
          secondary: const Color(0xFF10B981), // Emerald/Lime
          surface: Colors.white,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        textTheme: const TextTheme(
          bodySmall: TextStyle(fontSize: 13, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 15, color: Colors.black87),
          bodyLarge: TextStyle(fontSize: 17, color: Colors.black),
          titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return StarfieldBackground(
          child: PhoneFrame(child: child),
        );
      },
      initialRoute: '/dashboard',
      routes: {
        '/': (_) => const Scaffold(body: Center(child: Text('Login Page Placeholder'))),
        '/dashboard': (_) => const MainShell(initialIndex: 0),
        '/schedule': (_) => const MainShell(initialIndex: 1),
        '/medicene': (_) => const MedicinesScreen(),
        '/report': (_) => const MainShell(initialIndex: 2),
        '/scan': (_) => const ScanScreen(),
        '/add-medicine': (_) => const AddMedicineScreen(),
      },
    );
  }
}

class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  final List<Widget> _screens = const [
    HomeScreen(),
    ScheduleScreen(),
    StatsScreen(),
    Center(child: Text('Profile')), // Placeholder for Profile
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MedicineProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        height: 90,
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavBarItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  isSelected: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavBarItem(
                  icon: Icons.calendar_month_rounded,
                  label: 'Schedule',
                  isSelected: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                const SizedBox(width: 60), // Space for SCAN button
                _NavBarItem(
                  icon: Icons.bar_chart_rounded,
                  label: 'Report',
                  isSelected: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
                _NavBarItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: _currentIndex == 3,
                  onTap: () => setState(() => _currentIndex = 3),
                ),
              ],
            ),
            // Central SCAN Button
          Positioned(
            top: -30,
            left: 0,
            right: 0,
            child: Center(
              child: HoverScale(
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/scan'),
                  behavior: HitTestBehavior.translucent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC6FF00), // Lime Green
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFC6FF00).withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.document_scanner_rounded,
                          color: Colors.black,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'SCAN',
                        style: TextStyle(
                          color: Color(0xFFC6FF00),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverScale(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF6366F1) : Colors.grey[600],
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF6366F1) : Colors.grey[600],
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

