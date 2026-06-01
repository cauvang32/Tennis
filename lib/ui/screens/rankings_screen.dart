import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/tennis_models.dart';
import '../../repository/tennis_repository.dart';
import '../widgets/shared_widgets.dart';

/// RankingsScreen — Matches Kotlin RankingsScreen.kt with 3 tabs: Tổng, Theo mùa, Theo ngày.
class RankingsScreen extends StatefulWidget {
  final TennisRepository repo;
  final VoidCallback onShowLogin;

  const RankingsScreen({super.key, required this.repo, required this.onShowLogin});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _selectedSeasonId;
  String? _selectedDate;
  List<RankingEntry> _rankingsList = [];
  bool _isLocalLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    // Load lifetime rankings initially
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRankings());
    widget.repo.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    widget.repo.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    _loadRankings();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    _loadRankings();
  }

  Future<void> _loadRankings() async {
    if (!mounted) return;
    setState(() => _isLocalLoading = true);

    final initData = widget.repo.initData;
    switch (_tabController.index) {
      case 0:
        setState(() {
          _rankingsList = initData?.lifetimeRankings ?? [];
          _isLocalLoading = false;
        });
        break;
      case 1:
        final seasonId = _selectedSeasonId ?? initData?.activeSeason?.id ?? initData?.seasons?.firstOrNull?.id;
        if (seasonId != null) {
          _selectedSeasonId ??= seasonId;
          final res = await widget.repo.fetchSeasonRankings(seasonId);
          if (res != null && mounted) setState(() => _rankingsList = res);
        } else {
          if (mounted) setState(() => _rankingsList = []);
        }
        if (mounted) setState(() => _isLocalLoading = false);
        break;
      case 2:
        final date = _selectedDate ?? initData?.defaultDate;
        if (date != null) {
          _selectedDate ??= date;
          if (date == initData?.defaultDate && initData?.defaultDateRankings != null) {
            if (mounted) setState(() => _rankingsList = initData!.defaultDateRankings!);
          } else {
            final res = await widget.repo.fetchDateRankings(date);
            if (res != null && mounted) setState(() => _rankingsList = res);
          }
        }
        if (mounted) setState(() => _isLocalLoading = false);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: widget.repo,
      builder: (context, _) {
        return Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ScreenHeader(
                  repo: widget.repo,
                  icon: Icons.list,
                  title: 'Bảng xếp hạng',
                  onShowLogin: widget.onShowLogin,
                ),
                TabBar(
                  controller: _tabController,
                  indicatorColor: cs.primary,
                  labelColor: cs.primary,
                  unselectedLabelColor: cs.onSurfaceVariant,
                  tabs: const [
                    Tab(child: Text('Tổng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                    Tab(child: Text('Theo mùa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                    Tab(child: Text('Theo ngày', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                  ],
                ),
                // Season filter
                if (_tabController.index == 1) _buildSeasonFilter(cs),
                // Date filter
                if (_tabController.index == 2) _buildDateFilter(cs),
                // Column headers
                _buildHeaderRow(cs),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLocalLoading || widget.repo.isLoading
                      ? Center(child: CircularProgressIndicator(color: cs.primary))
                      : _rankingsList.isEmpty
                          ? Center(
                              child: Text('Không có bảng xếp hạng nào.',
                                  style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.only(bottom: 16),
                              itemCount: _sortedRankings.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, i) => _RankingRow(
                                pos: i + 1,
                                entry: _sortedRankings[i],
                                brandPrimary: cs.primary,
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

  List<RankingEntry> get _sortedRankings {
    final list = List<RankingEntry>.from(_rankingsList);
    list.sort((a, b) {
      final cmp = b.points.compareTo(a.points);
      if (cmp != 0) return cmp;
      final cmp2 = (b.winPercentage ?? 0).compareTo(a.winPercentage ?? 0);
      if (cmp2 != 0) return cmp2;
      return a.name.compareTo(b.name);
    });
    return list;
  }

  Widget _buildSeasonFilter(ColorScheme cs) {
    final seasons = widget.repo.initData?.seasons ?? [];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text('Season:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(width: 12),
          Expanded(
            child: _DropdownFilterButton<int>(
              value: _selectedSeasonId,
              items: seasons.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 12)))).toList(),
              hint: 'Chọn tournament season...',
              cs: cs,
              onChanged: (v) {
                setState(() => _selectedSeasonId = v);
                _loadRankings();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter(ColorScheme cs) {
    final dates = widget.repo.initData?.playDateStrings ?? [];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text('Play Date:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(width: 12),
          Expanded(
            child: _DropdownFilterButton<String>(
              value: _selectedDate,
              items: dates.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))).toList(),
              hint: 'Choose summary date...',
              cs: cs,
              onChanged: (v) {
                setState(() => _selectedDate = v);
                _loadRankings();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(ColorScheme cs) {
    const style = TextStyle(fontSize: 10, fontWeight: FontWeight.bold);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: cs.outlineVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('#', style: style.copyWith(color: cs.onSurfaceVariant))),
          Expanded(flex: 15, child: Text('NGƯỜI CHƠI', style: style.copyWith(color: cs.onSurfaceVariant))),
          Expanded(flex: 6, child: Text('ĐIỂM', style: style.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center)),
          Expanded(flex: 8, child: Text('T-B', style: style.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center)),
          Expanded(flex: 8, child: Text('THẮNG %', style: style.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center)),
          Expanded(flex: 11, child: Text('TIỀN PHẠT', style: style.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _DropdownFilterButton<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final String hint;
  final ColorScheme cs;
  final ValueChanged<T?> onChanged;

  const _DropdownFilterButton({
    required this.value,
    required this.items,
    required this.hint,
    required this.cs,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        border: Border.all(color: cs.primary, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurface)),
          items: items,
          onChanged: onChanged,
          icon: Icon(Icons.arrow_drop_down, color: cs.primary, size: 20),
          menuMaxHeight: 240,
        ),
      ),
    );
  }
}

class _RankingRow extends StatelessWidget {
  final int pos;
  final RankingEntry entry;
  final Color brandPrimary;

  const _RankingRow({required this.pos, required this.entry, required this.brandPrimary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nf = NumberFormat.decimalPattern();
    final winPct = entry.winPercentage ?? 0.0;
    final moneyRaw = entry.moneyLost ?? 0;

    return Card(
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                // Position badge
                SizedBox(
                  width: 28,
                  child: _positionBadge(pos, cs),
                ),
                // Name
                Expanded(
                  flex: 15,
                  child: Text(entry.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onSurface)),
                ),
                // Points
                Expanded(
                  flex: 6,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(4)),
                      child: Text(entry.points.toString(),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: brandPrimary)),
                    ),
                  ),
                ),
                // W-L
                Expanded(
                  flex: 8,
                  child: Text('${entry.wins}-${entry.losses}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface),
                      textAlign: TextAlign.center),
                ),
                // Win %
                Expanded(
                  flex: 8,
                  child: Text('${winPct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: winPct >= 50 ? cs.onTertiaryContainer : cs.error,
                      ),
                      textAlign: TextAlign.center),
                ),
                // Money Lost
                Expanded(
                  flex: 11,
                  child: Text(
                    moneyRaw > 0 ? '-${nf.format(moneyRaw)}đ' : '0đ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: moneyRaw > 0 ? cs.error : cs.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            // Form row
            if (entry.formStrings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 28),
                child: Row(
                  children: [
                    Text('Phong độ:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 6),
                    ...entry.formStrings.take(5).map((f) {
                      final isWin = f == 'W';
                      return Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: isWin ? cs.onTertiaryContainer : cs.error,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(f, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: cs.surface)),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _positionBadge(int pos, ColorScheme cs) {
    final Color? badgeColor = switch (pos) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => null,
    };
    if (badgeColor != null) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(pos.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black)),
      );
    }
    return Text(pos.toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant));
  }
}
