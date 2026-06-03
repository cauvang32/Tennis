import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'repository/tennis_repository.dart';
import 'utils/notification_helper.dart';
import 'utils/push_notifications.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/rankings_screen.dart';
import 'ui/screens/seasons_screen.dart';
import 'ui/screens/players_screen.dart';
import 'ui/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Graceful Firebase init — if google-services.json / GoogleService-Info.plist
  // are missing (e.g. fresh checkout before FCM_SETUP.md is followed),
  // the app still runs, just without push notifications.
  final firebaseReady = await _initFirebase();
  final repo = TennisRepository();
  await repo.initialize();
  await NotificationHelper().initialize();
  if (firebaseReady) {
    await PushNotifications().initialize(repo);
  }
  runApp(TennisProApp(repo: repo));
}

Future<bool> _initFirebase() async {
  try {
    await Firebase.initializeApp();
    return true;
  } catch (e, st) {
    debugPrint('[main] Firebase.initializeApp failed (config files likely '
        'missing — see FCM_SETUP.md): $e\n$st');
    return false;
  }
}

class TennisProApp extends StatelessWidget {
  final TennisRepository repo;
  const TennisProApp({super.key, required this.repo});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final systemBrightness = MediaQueryData.fromView(View.of(context)).platformBrightness;
        final isDark = repo.themeOverride ?? (systemBrightness == Brightness.dark);
        // Adapt the system UI overlay (status bar / nav bar) to the
        // resolved theme so icons stay visible in both modes. Single
        // SystemUiOverlayStyle — previous code had a ternary with two
        // byte-identical branches that hid the per-mode values.
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: isDark ? const Color(0xFF1A1C1E) : const Color(0xFFFDFBFF),
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ));

        return MaterialApp(
          title: 'Tennis Pro',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: repo.themeOverride == null ? ThemeMode.system : (isDark ? ThemeMode.dark : ThemeMode.light),
          home: MainAppShell(repo: repo),
        );
      },
    );
  }
}

class MainAppShell extends StatefulWidget {
  final TennisRepository repo;
  const MainAppShell({super.key, required this.repo});
  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> with WidgetsBindingObserver {
  int _activeTab = 0;
  bool _isLoginOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.repo.fetchInitData();
    widget.repo.startBackgroundSync();

    // First-launch notification permission popup. Idempotent — only
    // shows when the OS permission is actually missing. Returns true
    // if the user tapped 'Cho phép'; we then re-register the FCM
    // token so iOS devices (whose APNs token only arrives after the
    // system prompt) get persisted on this very launch.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final granted = await NotificationHelper()
          .requestPermissionOnFirstLaunch(context);
      if (granted) {
        await PushNotifications().refreshToken(widget.repo);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.repo.stopBackgroundSync();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.repo.startBackgroundSync();
    } else if (state == AppLifecycleState.paused) {
      widget.repo.stopBackgroundSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Scaffold(
          bottomNavigationBar: NavigationBar(
            backgroundColor: cs.surface,
            elevation: 8,
            height: 80,
            selectedIndex: _activeTab,
            onDestinationSelected: (i) => setState(() { _activeTab = i; _isLoginOpen = false; }),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.star), label: 'Trực tiếp'),
              NavigationDestination(icon: Icon(Icons.list), label: 'BXH'),
              NavigationDestination(icon: Icon(Icons.date_range), label: 'Mùa giải'),
              NavigationDestination(icon: Icon(Icons.face), label: 'Người chơi'),
            ],
          ),
          body: SafeArea(
            child: _isLoginOpen
                ? LoginScreen(repo: widget.repo, onLoginSuccess: () => setState(() => _isLoginOpen = false))
                : _buildTab(),
          ),
        ),
        if (_isLoginOpen)
          Positioned(
            top: 48,
            right: 24,
            child: GestureDetector(
              onTap: () => setState(() => _isLoginOpen = false),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: cs.outlineVariant, shape: BoxShape.circle),
                child: Icon(Icons.close, color: cs.onSurfaceVariant, size: 20),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTab() {
    void showLogin() => setState(() => _isLoginOpen = true);
    // IndexedStack (not switch + new instance each rebuild) keeps all four
    // tab screens mounted at once. Without this, switching tabs disposes
    // the dashboard's State and remounts it with an empty _matchesList
    // (the new initState doesn't fetch — it only subscribes to the repo,
    // so the screen would sit empty until the next notifyListeners).
    return IndexedStack(
      index: _activeTab,
      children: [
        DashboardScreen(repo: widget.repo, onShowLogin: showLogin),
        RankingsScreen(repo: widget.repo, onShowLogin: showLogin),
        SeasonsScreen(repo: widget.repo, onShowLogin: showLogin),
        PlayersScreen(repo: widget.repo, onShowLogin: showLogin),
      ],
    );
  }
}
