import 'package:flutter/material.dart';
import '../../models/tennis_models.dart';
import '../../repository/tennis_repository.dart';
import '../widgets/shared_widgets.dart';

/// PlayersScreen — Matches Kotlin PlayersScreen.kt.
/// Grid of player cards with search, create dialog, delete confirmation.
class PlayersScreen extends StatefulWidget {
  final TennisRepository repo;
  final VoidCallback onShowLogin;

  const PlayersScreen({super.key, required this.repo, required this.onShowLogin});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: widget.repo,
      builder: (context, _) {
        final allPlayers = widget.repo.initData?.players ?? [];
        final query = _searchCtrl.text.trim().toLowerCase();
        final filtered = query.isEmpty
            ? allPlayers
            : allPlayers.where((p) => p.name.toLowerCase().contains(query)).toList();

        return Scaffold(
          floatingActionButton: widget.repo.isAuthenticated && widget.repo.currentUser?.role == 'admin'
              ? FloatingActionButton(
                  onPressed: () => _showCreatePlayerDialog(context),
                  backgroundColor: cs.primary,
                  child: Icon(Icons.add, color: cs.surface),
                )
              : null,
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ScreenHeader(
                  repo: widget.repo,
                  icon: Icons.person,
                  title: 'Danh sách VĐV',
                  onShowLogin: widget.onShowLogin,
                ),
                if (!widget.repo.isAuthenticated)
                  AdminLoginBanner(
                    onTap: widget.onShowLogin,
                    message: 'Đăng nhập với quyền Quản trị viên để quản lý danh sách.',
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Lọc theo tên...',
                      prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: cs.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: widget.repo.isLoading
                      ? Center(child: CircularProgressIndicator(color: cs.primary))
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                query.isEmpty ? 'No players found.' : "No players match '$query'",
                                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.only(bottom: 80),
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 400,
                                childAspectRatio: 4,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                return _PlayerCard(
                                  player: filtered[i],
                                  isAdmin: widget.repo.isAuthenticated && widget.repo.currentUser?.role == 'admin',
                                  onDelete: () => _confirmDeletePlayer(context, filtered[i]),
                                  brandColor: cs.primary,
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreatePlayerDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Đăng Ký VĐV', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null)
                Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12, fontWeight: FontWeight.bold)),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Tên hiển thị VĐV'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  setDialogState(() => error = 'Please enter a valid player name.');
                  return;
                }
                final success = await widget.repo.createPlayer(nameCtrl.text.trim());
                if (!ctx.mounted) return;
                if (success) {
                  Navigator.pop(ctx);
                } else {
                  // Keep the dialog open so the user can adjust the name
                  // and retry; surface the repo's error via SnackBar.
                  showErrorSnack(ctx, widget.repo.errorMessage);
                }
              },
              child: const Text('Đăng Ký'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePlayer(BuildContext context, Player player) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa VĐV', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Bạn có chắc chắn muốn xóa VĐV '${player.name}'? Hành động này không thể hoàn tác."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final success = await widget.repo.deletePlayer(player.id);
              if (!ctx.mounted) return;
              // Always close the delete dialog (destructive action —
              // user shouldn't be stuck looking at it). On failure, the
              // SnackBar surfaces the error so the user knows it didn't
              // take effect.
              Navigator.pop(ctx);
              if (!success) {
                showErrorSnack(ctx, widget.repo.errorMessage);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Xóa VĐV'),
          ),
        ],
      ),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final Player player;
  final bool isAdmin;
  final VoidCallback onDelete;
  final Color brandColor;

  const _PlayerCard({required this.player, required this.isAdmin, required this.onDelete, required this.brandColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: cs.secondaryContainer,
              child: Icon(Icons.person, color: brandColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(player.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  const SizedBox(height: 4),
                  Text('ID: #${player.id}', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            if (isAdmin)
              IconButton(
                onPressed: onDelete,
                style: IconButton.styleFrom(backgroundColor: cs.errorContainer),
                icon: Icon(Icons.delete, color: cs.error, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
