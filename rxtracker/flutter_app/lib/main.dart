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
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const MainShell(),
      routes: {
        '/scan': (_) => const ScanScreen(),
        '/add-medicine': (_) => const AddMedicineScreen(),
        '/history': (_) => const HistoryScreen(),
        '/stats': (_) => const StatsScreen(),
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    HistoryScreen(),
    StatsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Initial data fetch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MedicineProvider>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Stats'),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _showAddOptions(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Medicine'),
            )
          : null,
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.document_scanner),
              title: const Text('Scan Prescription'),
              subtitle: const Text('Use camera or gallery'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/scan');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Add Manually'),
              subtitle: const Text('Enter medicine details'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/add-medicine');
              },
            ),
          ],
        ),
      ),
    );
  }
}
