import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/broadcast_service.dart';
import 'services/notification_service.dart';
import 'providers/tailor_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/udhaar_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 🔐 Load environment variables from .env file
  await dotenv.load(fileName: '.env');

  Object? firebaseInitError;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    firebaseInitError = e;
  }

  await NotificationService().initialize();
  await BroadcastService().initialize();

  runApp(MasterTailorApp(firebaseInitError: firebaseInitError));
}

class MasterTailorApp extends StatefulWidget {
  final Object? firebaseInitError;

  const MasterTailorApp({super.key, this.firebaseInitError});

  @override
  State<MasterTailorApp> createState() => _MasterTailorAppState();
}

class _MasterTailorAppState extends State<MasterTailorApp>
    with WidgetsBindingObserver {
  final NotificationService _notificationService = NotificationService();
  bool _wasInBackground = false;
  DateTime? _lastPausedAt;
  DateTime? _lastResumeNotificationAt;
  final Duration _minBackgroundDuration = const Duration(seconds: 5);
  final Duration _resumeNotifyCooldown = const Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Handles background persistence and system interruptions like incoming calls.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _wasInBackground = true;
      _lastPausedAt = DateTime.now();
      debugPrint('App paused: Saving state...');
      return;
    }

    if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      final now = DateTime.now();
      final pausedAt = _lastPausedAt;
      final wasLongEnough =
          pausedAt == null ||
          now.difference(pausedAt) >= _minBackgroundDuration;
      final lastShownAt = _lastResumeNotificationAt;
      final isCooldownOver =
          lastShownAt == null ||
          now.difference(lastShownAt) >= _resumeNotifyCooldown;

      if (wasLongEnough && isCooldownOver) {
        _lastResumeNotificationAt = now;
        _notificationService.showWelcomeBackNotification();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TailorProvider()..init(),
      child: MaterialApp(
        title: 'Tailor Master',
        debugShowCheckedModeBanner: false,
        builder: (context, child) => BroadcastOverlay(child: child),
        // ── Smooth transitions + swipe-back gesture on all platforms ──────
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF065F46), // deep emerald green
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: Colors.white,
          // Enable swipe-back (Cupertino style) on Android + web + desktop
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: CupertinoPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
              TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
            },
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF065F46),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          textTheme: const TextTheme(
            // Large, clear text for less tech-savvy users.
            bodyLarge: TextStyle(fontSize: 16),
            bodyMedium: TextStyle(fontSize: 15),
            titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        home: widget.firebaseInitError == null
            ? const AuthGate()
            : FirebaseInitErrorScreen(error: widget.firebaseInitError),
      ),
    );
  }
}

class BroadcastOverlay extends StatelessWidget {
  final Widget? child;

  const BroadcastOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: BroadcastService().offlineStream,
      initialData: false,
      builder: (context, snapshot) {
        final isOffline = snapshot.data ?? false;
        final content = child ?? const SizedBox.shrink();
        if (!isOffline) return content;

        return Stack(
          children: [
            content,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  color: Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: const Text(
                    'Working Offline - Data will sync later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class FirebaseInitErrorScreen extends StatelessWidget {
  final Object? error;

  const FirebaseInitErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Firebase could not be initialized.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'If you are running on Web/Desktop, you typically need to run FlutterFire configuration and initialize with platform options.',
            ),
            const SizedBox(height: 12),
            SelectableText('Error: $error'),
          ],
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Authentication')),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Something went wrong while checking sign-in status.\n\n${snapshot.error}',
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) return const LoginScreen();

        // MainScreen contains DashboardScreen and the app shell.
        return const MainScreen();
      },
    );
  }
}

// ─── App Shell ────────────────────────────────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  // 🚀 Cache screens to prevent expensive widget recreation
  late final List<Widget> _cachedScreens;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);

    // Build screens once and cache them
    _cachedScreens = [
      DashboardScreen(onNavigate: _onTabSelected),
      CustomersScreen(onBack: () => _onTabSelected(0)),
      UdhaarScreen(onBack: () => _onTabSelected(0)),
      OrdersScreen(onBack: () => _onTabSelected(0)),
      SettingsScreen(onBack: () => _onTabSelected(0)),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
    } else {
      setState(() => _currentIndex = index);
    }
  }

  void _onPageChanged(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    const emerald = Color(0xFF065F46);

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _onTabSelected(0);
        }
      },
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const _QuickSwipeScrollPhysics(),
          allowImplicitScrolling: true,
          children: _cachedScreens, // 🚀 Use cached screens
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          backgroundColor: Colors.white,
          indicatorColor: emerald.withValues(alpha: 0.15),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_alt_rounded),
              label: 'Customers',
            ),
            NavigationDestination(
              icon: Icon(Icons.money_off_csred_outlined),
              selectedIcon: Icon(Icons.money_off_csred_rounded),
              label: 'Udhaar',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt_rounded),
              label: 'Orders',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSwipeScrollPhysics extends PageScrollPhysics {
  const _QuickSwipeScrollPhysics({super.parent});

  @override
  _QuickSwipeScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _QuickSwipeScrollPhysics(parent: buildParent(ancestor));
  }

  // Reduce swipe distance needed to change pages.
  @override
  double get dragStartDistanceMotionThreshold => 3.0;
}
