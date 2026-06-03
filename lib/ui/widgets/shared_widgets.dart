import 'package:flutter/material.dart';
import '../../repository/tennis_repository.dart';

/// Show a red floating SnackBar with the repo's last error message, or a
/// generic Vietnamese fallback. Used by every dialog onPressed that issues
/// an async CRUD call and needs to surface a server-side failure.
void showErrorSnack(BuildContext context, String? message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message ?? 'Đã xảy ra lỗi. Vui lòng thử lại.'),
      backgroundColor: Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ));
}

/// Shared header bar with login/logout and theme toggle — replicated on every screen.
class ScreenHeader extends StatelessWidget {
  final TennisRepository repo;
  final IconData icon;
  final String title;
  final VoidCallback? onShowLogin;

  const ScreenHeader({
    super.key,
    required this.repo,
    required this.icon,
    required this.title,
    this.onShowLogin,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAuth = repo.isAuthenticated;

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: cs.primary, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: cs.onSurface,
              ),
            ),
          ),
          if (!isAuth && onShowLogin != null)
            _LoginButton(onShowLogin: onShowLogin!, cs: cs),
          if (isAuth) _LogoutButton(repo: repo, cs: cs),
          _ThemeToggle(repo: repo),
        ],
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final VoidCallback onShowLogin;
  final ColorScheme cs;
  const _LoginButton({required this.onShowLogin, required this.cs});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: FilledButton.icon(
        onPressed: onShowLogin,
        icon: Icon(Icons.lock, size: 14, color: cs.surface),
        label: Text('Đăng Nhập', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.surface)),
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final TennisRepository repo;
  final ColorScheme cs;
  const _LogoutButton({required this.repo, required this.cs});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: FilledButton.icon(
        onPressed: () => repo.logoutAction(),
        icon: Icon(Icons.exit_to_app, size: 14, color: cs.error),
        label: Text('Đăng Xuất', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.error)),
        style: FilledButton.styleFrom(
          backgroundColor: cs.errorContainer,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  final TennisRepository repo;
  const _ThemeToggle({required this.repo});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = repo.themeOverride ?? (brightness == Brightness.dark);
    return IconButton(
      onPressed: () => repo.toggleThemeOption(),
      icon: Text(isDark ? '☀️' : '🌙', style: const TextStyle(fontSize: 18)),
    );
  }
}

/// Admin login banner shown on every screen when not authenticated.
class AdminLoginBanner extends StatelessWidget {
  final VoidCallback onTap;
  final String message;

  const AdminLoginBanner({
    super.key,
    required this.onTap,
    this.message = 'Đăng nhập với quyền Quản trị viên để quản lý.',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(Icons.info, color: cs.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
                ),
              ),
              Text('Login', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary)),
            ],
          ),
        ),
      ),
    );
  }
}
