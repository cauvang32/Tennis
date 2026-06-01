import 'package:flutter/material.dart';
import 'repository/tennis_repository.dart';
import 'utils/notification_helper.dart';
import 'ui/theme/app_theme.dart';
import 'ui/screens/dashboard_screen.dart';
import 'ui/screens/rankings_screen.dart';
import 'ui/screens/seasons_screen.dart';
import 'ui/screens/players_screen.dart';
import 'ui/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = TennisRepository();
  await repo.initialize();
  await NotificationHelper().initialize();
  runApp(TennisProApp(repo: repo));
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
    return switch (_activeTab) {
      0 => DashboardScreen(repo: widget.repo, onShowLogin: showLogin),
      1 => RankingsScreen(repo: widget.repo, onShowLogin: showLogin),
      2 => SeasonsScreen(repo: widget.repo, onShowLogin: showLogin),
      3 => PlayersScreen(repo: widget.repo, onShowLogin: showLogin),
      _ => DashboardScreen(repo: widget.repo, onShowLogin: showLogin),
    };
  }
}
