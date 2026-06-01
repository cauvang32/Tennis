import 'package:flutter/material.dart';
import '../../models/tennis_models.dart';
import '../../repository/tennis_repository.dart';

/// LoginScreen — Matches Kotlin LoginScreen.kt exactly.
/// Shows login form when unauthenticated, user profile + logout when authenticated.
class LoginScreen extends StatefulWidget {
  final TennisRepository repo;
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.repo, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _passwordVisible = false;

  TennisRepository get repo => widget.repo;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    if (_usernameCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) return;
    final success = await repo.login(
      LoginRequest(username: _usernameCtrl.text.trim(), password: _passwordCtrl.text),
    );
    if (success && mounted) widget.onLoginSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: repo.isAuthenticated && repo.currentUser != null
                ? _buildLoggedInPanel(cs)
                : _buildLoginForm(cs),
          ),
        );
      },
    );
  }

  Widget _buildLoggedInPanel(ColorScheme cs) {
    final user = repo.currentUser!;
    return Card(
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.person, color: cs.surface, size: 36),
            ),
            const SizedBox(height: 16),
            Text('Authorized Account Active',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 16),
            Text(user.displayName ?? user.username ?? 'User',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: cs.primary)),
            Text('Assigned Role: ${(user.role ?? 'viewer').toUpperCase()}',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
            if (user.email != null && user.email!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(user.email!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => repo.logoutAction(),
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(backgroundColor: cs.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(ColorScheme cs) {
    return Card(
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quyền Quản trị',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text(
              'Đăng nhập bằng tên đăng nhập và mật khẩu để quản lý giải đấu, danh sách người chơi, ghi nhận kết quả và cài đặt mùa giải.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.3),
            ),
            const SizedBox(height: 16),
            if (repo.errorMessage != null) ...[
              Card(
                color: cs.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(repo.errorMessage!,
                      style: TextStyle(color: cs.error, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _usernameCtrl,
              decoration: InputDecoration(
                labelText: 'Tên đăng nhập',
                hintText: 'Nhập tên đăng nhập',
                prefixIcon: Icon(Icons.person, color: cs.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary),
                ),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: !_passwordVisible,
              decoration: InputDecoration(
                labelText: 'Mật khẩu',
                hintText: 'Nhập mật khẩu',
                prefixIcon: Icon(Icons.lock, color: cs.primary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                    color: cs.primary,
                  ),
                  onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: cs.primary),
                ),
              ),
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _doLogin(),
            ),
            const SizedBox(height: 16),
            if (repo.isLoading)
              Center(child: CircularProgressIndicator(color: cs.primary))
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _doLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Xác thực Tài khoản',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
