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
import 'screens/profile_screen.dart';
import 'widgets/starfield_background.dart';
import 'widgets/phone_frame.dart';
import 'widgets/hover_scale.dart';
import 'widgets/rx_bottom_nav_bar.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://ajfvpzgydcerahgiwtah.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFqZnZwemd5ZGNlcmFoZ2l3dGFoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxNTk2MDAsImV4cCI6MjA5MzczNTYwMH0.UK7u8jKelGs2h4tMLunfpgxzG-HASQyjJN941I0TBQc',
  );

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
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          final session = snapshot.data?.session;
          if (session != null) {
            return const MainShell();
          }
          return const AuthScreen();
        },
      ),
      routes: {
        '/dashboard': (_) => const MainShell(initialIndex: 0),
        '/schedule': (_) => const MainShell(initialIndex: 1),
        '/medicene': (_) => const MedicinesScreen(),
        '/report': (_) => const MainShell(initialIndex: 2),
        '/profile': (_) => const MainShell(initialIndex: 3),
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
  late PageController _pageController;

  // Re-ordered to match the bottom nav bar in the image:
  // Home, Schedule, Scan, Report, Profile
  final List<Widget> _screens = const [
    HomeScreen(),
    MedicinesScreen(), // This is the "Medication Bag"
    ScanScreen(),      // Integrated into PageView for sliding animation
    StatsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MedicineProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onNavTap(int index) {
    if (_currentIndex == index) return;
    
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Removed AppBar to let each screen handle its own header (matching the design image)
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const NeverScrollableScrollPhysics(), 
        children: [
          HomeScreen(onBagTap: () => _onNavTap(1)),
          const MedicinesScreen(),
          ScanScreen(onBack: () => _onNavTap(0)),
          const StatsScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: RxBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
