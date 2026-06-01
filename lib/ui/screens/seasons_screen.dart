import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/tennis_models.dart';
import '../../repository/tennis_repository.dart';
import '../widgets/shared_widgets.dart';

/// SeasonsScreen — Matches Kotlin SeasonsScreen.kt.
/// List of seasons with create/end/delete/roster management dialogs.
class SeasonsScreen extends StatefulWidget {
  final TennisRepository repo;
  final VoidCallback onShowLogin;

  const SeasonsScreen({super.key, required this.repo, required this.onShowLogin});

  @override
  State<SeasonsScreen> createState() => _SeasonsScreenState();
}

class _SeasonsScreenState extends State<SeasonsScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: widget.repo,
      builder: (context, _) {
        final seasons = widget.repo.initData?.seasons ?? [];
        final isAdmin = widget.repo.isAuthenticated && widget.repo.currentUser?.role == 'admin';
        final isEditorOrAdmin = widget.repo.isAuthenticated &&
            (widget.repo.currentUser?.role == 'admin' || widget.repo.currentUser?.role == 'editor');

        return Scaffold(
          floatingActionButton: isAdmin
              ? FloatingActionButton(
                  onPressed: () => _showCreateSeasonDialog(context),
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
                  icon: Icons.date_range,
                  title: 'Mùa giải',
                  onShowLogin: widget.onShowLogin,
                ),
                if (!widget.repo.isAuthenticated)
                  AdminLoginBanner(
                    onTap: widget.onShowLogin,
                    message: 'Đăng nhập với tư cách Quản trị viên/Biên tập viên để tạo và kết thúc mùa giải.',
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: widget.repo.isLoading
                      ? Center(child: CircularProgressIndicator(color: cs.primary))
                      : seasons.isEmpty
                          ? Center(
                              child: Text('Chưa có giải đấu nào được thêm.',
                                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 80),
                              itemCount: seasons.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (context, i) => _SeasonCard(
                                season: seasons[i],
                                isAdmin: isAdmin,
                                isEditorOrAdmin: isEditorOrAdmin,
                                repo: widget.repo,
                                onEnd: () => _confirmEndSeason(context, seasons[i]),
                                onDelete: () => _confirmDeleteSeason(context, seasons[i]),
                                onManageRoster: () => _showRosterDialog(context, seasons[i]),
                              ),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateSeasonDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final startCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final endCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final moneyCtrl = TextEditingController(text: '20000');
    bool autoEnd = false;
    final selectedPlayerIds = <int>{};
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final players = widget.repo.initData?.players ?? [];
          return AlertDialog(
            title: const Text('Tạo Giải Đấu Mới', style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (error != null)
                    Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12, fontWeight: FontWeight.bold)),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên Giải Đấu')),
                  const SizedBox(height: 8),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Mô tả ngắn gọn')),
                  const SizedBox(height: 8),
                  TextField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Ngày bắt đầu (YYYY-MM-DD)')),
                  const SizedBox(height: 8),
                  TextField(controller: endCtrl, decoration: const InputDecoration(labelText: 'Ngày kết thúc (Tùy chọn YYYY-MM-DD)')),
                  Row(children: [
                    Checkbox(value: autoEnd, onChanged: (v) => setDialogState(() => autoEnd = v ?? false)),
                    const Expanded(child: Text('Tự động kết thúc khi qua ngày hạn', style: TextStyle(fontSize: 12))),
                  ]),
                  TextField(controller: moneyCtrl, decoration: const InputDecoration(labelText: 'Mức phạt tiền (đ)'), keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  const Text('Chọn Danh Sách VĐV Ban Đầu:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ...players.map((p) => CheckboxListTile(
                        dense: true,
                        title: Text(p.name, style: const TextStyle(fontSize: 13)),
                        value: selectedPlayerIds.contains(p.id),
                        onChanged: (v) => setDialogState(() {
                          if (v == true) {
                            selectedPlayerIds.add(p.id);
                          } else {
                            selectedPlayerIds.remove(p.id);
                          }
                        }),
                      )),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
              FilledButton(
                onPressed: () async {
                  final money = int.tryParse(moneyCtrl.text);
                  if (nameCtrl.text.trim().isEmpty) {
                    setDialogState(() => error = 'Please specify a season name.');
                    return;
                  }
                  if (money == null) {
                    setDialogState(() => error = 'Please specify a valid numeric penalty.');
                    return;
                  }
                  if (autoEnd && endCtrl.text.trim().isEmpty) {
                    setDialogState(() => error = 'End Date is required if auto-end is enabled.');
                    return;
                  }
                  final success = await widget.repo.createSeason(CreateSeasonRequest(
                    name: nameCtrl.text.trim(),
                    startDate: startCtrl.text.trim(),
                    endDate: endCtrl.text.trim().isEmpty ? null : endCtrl.text.trim(),
                    autoEnd: autoEnd,
                    loseMoneyPerLoss: money,
                    playerIds: selectedPlayerIds.toList(),
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  ));
                  if (success && ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Khởi Tạo Giải Đấu'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmEndSeason(BuildContext context, Season season) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kết thúc Mùa Giải', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Bạn có chắc chắn muốn kết thúc mùa giải '${season.name}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
              await widget.repo.endSeason(season.id, today);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Kết thúc'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSeason(BuildContext context, Season season) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa Mùa Giải', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Bạn có chắc chắn muốn xóa mùa giải '${season.name}'? Toàn bộ dữ liệu liên quan sẽ bị xóa vĩnh viễn."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          FilledButton(
            onPressed: () async {
              await widget.repo.deleteSeason(season.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Xóa Mùa Giải'),
          ),
        ],
      ),
    );
  }

  void _showRosterDialog(BuildContext context, Season season) {
    showDialog(
      context: context,
      builder: (ctx) => _RosterDialog(repo: widget.repo, season: season),
    );
  }
}

class _SeasonCard extends StatelessWidget {
  final Season season;
  final bool isAdmin;
  final bool isEditorOrAdmin;
  final TennisRepository repo;
  final VoidCallback onEnd;
  final VoidCallback onDelete;
  final VoidCallback onManageRoster;

  const _SeasonCard({
    required this.season,
    required this.isAdmin,
    required this.isEditorOrAdmin,
    required this.repo,
    required this.onEnd,
    required this.onDelete,
    required this.onManageRoster,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nf = NumberFormat.decimalPattern();

    return Card(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(season.name,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: season.isActive ? cs.tertiaryContainer : cs.errorContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    season.isActive ? 'ACTIVE' : 'ENDED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: season.isActive ? cs.onTertiaryContainer : cs.error,
                    ),
                  ),
                ),
              ],
            ),
            if (season.description != null && season.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(season.description!, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 16),
            // Date range
            Row(children: [
              Icon(Icons.date_range, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Text('Thời gian: ${season.startDate} to ${season.endDate ?? "Present"}',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.star, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 12),
              Text('Tiền phạt: ${nf.format(season.loseMoneyPerLoss ?? 20000)}đ 1 trận',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
            ]),
            const Divider(height: 24),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: onManageRoster,
                  icon: Icon(Icons.person, color: cs.primary, size: 20),
                  label: Text('Danh sách', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.primary)),
                ),
                if (isEditorOrAdmin)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (season.isActive)
                        OutlinedButton(
                          onPressed: onEnd,
                          child: Text('Kết thúc', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.error)),
                        )
                      else
                        FilledButton(
                          onPressed: () => repo.reactivateSeason(season.id),
                          child: const Text('Bật lại', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      if (isAdmin) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: onDelete,
                          style: IconButton.styleFrom(backgroundColor: cs.errorContainer),
                          icon: Icon(Icons.delete, color: cs.error, size: 20),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterDialog extends StatefulWidget {
  final TennisRepository repo;
  final Season season;

  const _RosterDialog({required this.repo, required this.season});

  @override
  State<_RosterDialog> createState() => _RosterDialogState();
}

class _RosterDialogState extends State<_RosterDialog> {
  final _chosenIds = <int>{};
  List<Player> _assignedPlayers = [];
  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isEditorOrAdmin =>
      widget.repo.isAuthenticated &&
      (widget.repo.currentUser?.role == 'admin' || widget.repo.currentUser?.role == 'editor');

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    final assigned = await widget.repo.getSeasonPlayers(widget.season.id);
    if (mounted) {
      setState(() {
        _assignedPlayers = assigned;
        _chosenIds.addAll(assigned.map((p) => p.id));
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allPlayers = widget.repo.initData?.players ?? [];
    final title = _isEditorOrAdmin
        ? 'Gán người chơi: ${widget.season.name}'
        : 'Danh sách người chơi: ${widget.season.name}';

    return AlertDialog(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: cs.primary))
            : _isEditorOrAdmin
                ? ListView(
                    children: allPlayers
                        .map((p) => CheckboxListTile(
                              dense: true,
                              title: Text(p.name, style: const TextStyle(fontSize: 14)),
                              value: _chosenIds.contains(p.id),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _chosenIds.add(p.id);
                                } else {
                                  _chosenIds.remove(p.id);
                                }
                              }),
                            ))
                        .toList(),
                  )
                : _assignedPlayers.isEmpty
                    ? Center(
                        child: Text('Không có người chơi nào trong giải đấu này.',
                            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                      )
                    : ListView(
                        children: _assignedPlayers
                            .map((p) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text('• ${p.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                ))
                            .toList(),
                      ),
      ),
      actions: [
        if (_isEditorOrAdmin) ...[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          FilledButton(
            onPressed: _isSaving
                ? null
                : () async {
                    setState(() => _isSaving = true);
                    final success = await widget.repo.updateSeasonPlayers(widget.season.id, _chosenIds.toList());
                    if (success && context.mounted) Navigator.pop(context);
                  },
            child: _isSaving
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary))
                : const Text('Lưu DSTĐ'),
          ),
        ] else
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
      ],
    );
  }
}
