import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/tennis_models.dart';
import '../../repository/tennis_repository.dart';
import '../widgets/shared_widgets.dart';

class DashboardScreen extends StatefulWidget {
  final TennisRepository repo;
  final VoidCallback onShowLogin;
  const DashboardScreen({super.key, required this.repo, required this.onShowLogin});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? _filterDate;
  final int _filterType = 0; // 0=date, 1=season
  List<Match> _matchesList = [];

  @override
  void initState() {
    super.initState();
    widget.repo.addListener(_onRepoChanged);
    // Initial data fetch is issued by MainAppShell.initState. By the
    // time this screen mounts inside the IndexedStack the fetch is
    // already in flight; the listener picks up the result.
  }

  @override
  void dispose() {
    widget.repo.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (_filterType == 0 && (_filterDate == null || _filterDate == widget.repo.initData?.defaultDate)) {
      setState(() => _matchesList = widget.repo.initData?.defaultDateMatches ?? []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: widget.repo,
      builder: (context, _) {
        final isAuth = widget.repo.isAuthenticated;
        final user = widget.repo.currentUser;
        final canEdit = isAuth && (user?.role == 'admin' || user?.role == 'editor');

        return Scaffold(
          floatingActionButton: canEdit
              ? FloatingActionButton(
                  onPressed: () => _showCreateMatchDialog(context),
                  backgroundColor: cs.primary,
                  child: Icon(Icons.add, color: cs.surface),
                )
              : null,
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Header
                _buildHeader(cs, isAuth, user),
                Expanded(
                  child: ListView(
                    children: [
                      // Auth banner
                      if (!isAuth) _guestBanner(cs) else _authBanner(cs, user),
                      const SizedBox(height: 16),
                      // Featured match
                      _featuredMatch(cs),
                      const SizedBox(height: 16),
                      // Match list
                      if (widget.repo.isLoading)
                        SizedBox(height: 100, child: Center(child: CircularProgressIndicator(color: cs.primary)))
                      else if (_matchesList.isEmpty)
                        const SizedBox(height: 100, child: Center(child: Text('Chưa có trận đấu nào.')))
                      else
                        ..._matchesList.map((m) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _MatchCard(match: m, canEdit: canEdit, onDelete: () => _confirmDeleteMatch(context, m)),
                            )),
                      // Error
                      if (widget.repo.errorMessage != null) _errorCard(cs),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(ColorScheme cs, bool isAuth, User? user) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onShowLogin,
            child: CircleAvatar(radius: 20, backgroundColor: cs.primary, child: Icon(Icons.person, color: cs.surface)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isAuth ? (user?.displayName ?? user?.username ?? 'User') : 'Chế độ Khách',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cs.onSurface)),
              Row(children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: cs.onTertiaryContainer, shape: BoxShape.circle)),
                const SizedBox(width: 4),
                Text('api.hungsanity.com', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
              ]),
            ]),
          ),
          if (!isAuth)
            SizedBox(
              height: 32,
              child: FilledButton.icon(
                onPressed: widget.onShowLogin,
                icon: Icon(Icons.lock, size: 14, color: cs.surface),
                label: Text('Đăng Nhập', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.surface)),
                style: FilledButton.styleFrom(backgroundColor: cs.primary, padding: const EdgeInsets.symmetric(horizontal: 12)),
              ),
            )
          else
            SizedBox(
              height: 32,
              child: FilledButton.icon(
                onPressed: () => widget.repo.logoutAction(),
                icon: Icon(Icons.exit_to_app, size: 14, color: cs.error),
                label: Text('Đăng Xuất', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.error)),
                style: FilledButton.styleFrom(backgroundColor: cs.errorContainer, padding: const EdgeInsets.symmetric(horizontal: 12)),
              ),
            ),
          IconButton(
            onPressed: () => widget.repo.toggleThemeOption(),
            icon: Text(Theme.of(context).brightness == Brightness.dark ? '☀️' : '🌙', style: const TextStyle(fontSize: 18)),
          ),
          IconButton(
            onPressed: () => widget.repo.fetchInitData(),
            icon: Icon(Icons.refresh, color: cs.primary),
          ),
        ],
      ),
    );
  }

  Widget _guestBanner(ColorScheme cs) => Card(
        color: cs.secondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: widget.onShowLogin,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Icon(Icons.info, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Chế độ Khách (Chỉ xem)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
                  Text('Đăng nhập với tư cách Quản trị viên/Biên tập viên để quản lý giải đấu.',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ]),
              ),
              Icon(Icons.arrow_forward, color: cs.primary),
            ]),
          ),
        ),
      );

  Widget _authBanner(ColorScheme cs, User? user) => Card(
        color: cs.tertiaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(Icons.check, color: cs.onTertiaryContainer, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Đã xác thực: ${user?.role?.toUpperCase()} PANEL ACTIVE',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onTertiaryContainer)),
                Text('Welcome ${user?.displayName ?? user?.username}!',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ]),
            ),
          ]),
        ),
      );

  Widget _featuredMatch(ColorScheme cs) {
    final m = widget.repo.initData?.defaultDateMatches?.firstOrNull;
    if (m == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(4)),
            child: Text('TRẬN ĐẤU MỚI NHẤT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: cs.onSecondaryContainer)),
          ),
          Text('NGÀY THI ĐẤU • ${m.playDate}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary, fontFamily: 'monospace')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _playerAvatar(m.player1Name ?? 'A', m.matchType == 'duo' ? m.player2Name : null, cs, true)),
          Column(children: [
            Row(children: [
              Text('${m.team1Score}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: cs.onSecondaryContainer)),
              Text(' | ', style: TextStyle(fontSize: 20, color: cs.onSurfaceVariant)),
              Text('${m.team2Score}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: cs.onSecondaryContainer)),
            ]),
            Text('ĐỘI THẮNG: TEAM ${m.winningTeam}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.primary)),
          ]),
          Expanded(child: _playerAvatar(m.player3Name ?? 'B', m.matchType == 'duo' ? m.player4Name : null, cs, false)),
        ]),
      ]),
    );
  }

  Widget _playerAvatar(String name, String? partner, ColorScheme cs, bool highlight) {
    return Column(children: [
      CircleAvatar(
        radius: 27,
        backgroundColor: cs.surface,
        child: Icon(Icons.star, color: highlight ? cs.primary : cs.onSurfaceVariant, size: 24),
      ),
      const SizedBox(height: 6),
      Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onSurface), textAlign: TextAlign.center),
      if (partner != null)
        Text('& $partner', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant), textAlign: TextAlign.center),
    ]);
  }

  Widget _errorCard(ColorScheme cs) => Card(
        color: cs.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Icon(Icons.warning, color: cs.error),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.repo.errorMessage!, style: TextStyle(color: cs.error, fontSize: 12))),
            TextButton(onPressed: () => widget.repo.clearErrorMessage(), child: Text('Đóng', style: TextStyle(color: cs.error))),
          ]),
        ),
      );

  void _confirmDeleteMatch(BuildContext context, Match m) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa Trận Đấu', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc chắn muốn xóa trận đấu ngày ${m.playDate} (${m.player1Name} vs ${m.player3Name})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final success = await widget.repo.deleteMatch(m.id);
              if (!ctx.mounted) return;
              // Always close the delete dialog (destructive action);
              // surface server-side errors via SnackBar.
              Navigator.pop(ctx);
              if (!success) {
                showErrorSnack(ctx, widget.repo.errorMessage);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Xóa Trận Đấu'),
          ),
        ],
      ),
    );
  }

  void _showCreateMatchDialog(BuildContext context) {
    final seasons = widget.repo.initData?.seasons ?? [];
    final players = widget.repo.initData?.players ?? [];
    if (seasons.isEmpty || players.isEmpty) return;

    int selSeason = seasons.first.id;
    String playDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String matchType = 'solo';
    int p1 = players.first.id;
    int? p2;
    int p3 = players.length > 1 ? players[1].id : players.first.id;
    int? p4;
    final t1Ctrl = TextEditingController();
    final t2Ctrl = TextEditingController();
    int winTeam = 1;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Ghi kết quả trận đấu', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(shrinkWrap: true, children: [
              if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12, fontWeight: FontWeight.bold)),
              // Season
              DropdownButtonFormField<int>(
                initialValue: selSeason,
                decoration: const InputDecoration(labelText: 'Chọn mùa giải'),
                items: seasons.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                onChanged: (v) => ss(() => selSeason = v!),
              ),
              const SizedBox(height: 8),
              TextFormField(initialValue: playDate, decoration: const InputDecoration(labelText: 'Ngày thi đấu (YYYY-MM-DD)'), onChanged: (v) => playDate = v),
              const SizedBox(height: 8),
              Row(children: [
                ChoiceChip(label: const Text('Đơn (1v1)'), selected: matchType == 'solo', onSelected: (_) => ss(() { matchType = 'solo'; p2 = null; p4 = null; })),
                const SizedBox(width: 8),
                ChoiceChip(label: const Text('Đôi (2v2)'), selected: matchType == 'duo', onSelected: (_) => ss(() { matchType = 'duo'; p2 ??= players.length > 2 ? players[2].id : players[0].id; p4 ??= players.length > 3 ? players[3].id : (players.length > 1 ? players[1].id : players[0].id); })),
              ]),
              const SizedBox(height: 8),
              // Team 1
              Card(color: Theme.of(context).colorScheme.secondaryContainer, child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('VĐV ĐỘI 1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
                DropdownButtonFormField<int>(initialValue: p1, decoration: const InputDecoration(labelText: 'VĐV 1'), items: players.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(), onChanged: (v) => ss(() => p1 = v!)),
                if (matchType == 'duo') DropdownButtonFormField<int>(initialValue: p2, decoration: const InputDecoration(labelText: 'VĐV 2'), items: players.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(), onChanged: (v) => ss(() => p2 = v)),
                TextFormField(controller: t1Ctrl, decoration: const InputDecoration(labelText: 'Điểm trận Đội 1'), keyboardType: TextInputType.number),
              ]))),
              const SizedBox(height: 8),
              // Team 2
              Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('VĐV ĐỘI 2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                DropdownButtonFormField<int>(initialValue: p3, decoration: const InputDecoration(labelText: 'VĐV 3'), items: players.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(), onChanged: (v) => ss(() => p3 = v!)),
                if (matchType == 'duo') DropdownButtonFormField<int>(initialValue: p4, decoration: const InputDecoration(labelText: 'VĐV 4'), items: players.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(), onChanged: (v) => ss(() => p4 = v)),
                TextFormField(controller: t2Ctrl, decoration: const InputDecoration(labelText: 'Điểm trận Đội 2'), keyboardType: TextInputType.number),
              ]))),
              const SizedBox(height: 8),
              RadioGroup<int>(
                groupValue: winTeam,
                onChanged: (v) => ss(() => winTeam = v!),
                child: Row(children: [
                  const Text('Đội thắng: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  Radio<int>(value: 1),
                  const Text('Đội 1'),
                  Radio<int>(value: 2),
                  const Text('Đội 2'),
                ]),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            FilledButton(
              onPressed: () async {
                final s1 = int.tryParse(t1Ctrl.text);
                final s2 = int.tryParse(t2Ctrl.text);
                if (s1 == null || s2 == null) { ss(() => error = 'Please enter valid scores.'); return; }
                final ids = [p1, p3]; if (matchType == 'duo') { if (p2 == null || p4 == null) { ss(() => error = 'Select all 4 players.'); return; } ids.addAll([p2!, p4!]); }
                if (ids.toSet().length != ids.length) { ss(() => error = 'A player cannot be selected multiple times.'); return; }
                final success = await widget.repo.createMatch(CreateMatchRequest(seasonId: selSeason, playDate: playDate, player1Id: p1, player2Id: p2, player3Id: p3, player4Id: p4, team1Score: s1, team2Score: s2, winningTeam: winTeam, matchType: matchType));
                if (!ctx.mounted) return;
                if (success) {
                  Navigator.pop(ctx);
                } else {
                  // Keep the dialog open so the user can adjust scores
                  // / selections and retry; surface the server error.
                  showErrorSnack(ctx, widget.repo.errorMessage);
                }
              },
              child: const Text('Lưu kết quả'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final Match match;
  final bool canEdit;
  final VoidCallback onDelete;
  const _MatchCard({required this.match, required this.canEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(6)),
              child: Text('Mode: ${match.matchType.toUpperCase()}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.surface)),
            ),
            Row(children: [
              Text(match.playDate, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
              if (canEdit) ...[const SizedBox(width: 8), GestureDetector(onTap: onDelete, child: Icon(Icons.delete, color: cs.error, size: 20))],
            ]),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(flex: 15, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(match.player1Name ?? 'Player A', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: match.winningTeam == 1 ? cs.primary : cs.onSurface)),
              if (match.matchType == 'duo' && match.player2Name != null) Text(match.player2Name!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: match.winningTeam == 1 ? cs.primary : cs.onSurface)),
            ])),
            Expanded(flex: 10, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${match.team1Score}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: match.winningTeam == 1 ? cs.primary : cs.onSurfaceVariant)),
              Text(' - ', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
              Text('${match.team2Score}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: match.winningTeam == 2 ? cs.primary : cs.onSurfaceVariant)),
            ])),
            Expanded(flex: 15, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(match.player3Name ?? 'Player B', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: match.winningTeam == 2 ? cs.primary : cs.onSurface)),
              if (match.matchType == 'duo' && match.player4Name != null) Text(match.player4Name!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: match.winningTeam == 2 ? cs.primary : cs.onSurface)),
            ])),
          ]),
        ]),
      ),
    );
  }
}
