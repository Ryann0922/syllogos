import 'package:flutter/material.dart';
import 'package:syllogos/services/storage_service.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  int startMonth = 9;
  DateTimeRange? yearRange;
  List<Map> classes = [];
  List<Map> entries = [];
  Map<String, Map<String, dynamic>> stats = {};

  @override
  void initState() {
    super.initState();
    final s = StorageService.getSettings();
    if (s.containsKey('startMonth')) startMonth = s['startMonth'];
    _computeRange();
    _loadData();
  }

  void _computeRange() {
    final s = StorageService.getSettings();
    final selectedStart = s['selectedSchoolYearStart'];
    if (selectedStart != null) {
      final start = DateTime(selectedStart as int, startMonth, 1);
      final end = DateTime(
        selectedStart + 1,
        startMonth,
        1,
      ).subtract(const Duration(days: 1));
      yearRange = DateTimeRange(start: start, end: end);
      return;
    }
    final now = DateTime.now();
    final startYear = (now.month >= startMonth) ? now.year : now.year - 1;
    final start = DateTime(startYear, startMonth, 1);
    final end = DateTime(
      startYear + 1,
      startMonth,
      1,
    ).subtract(const Duration(days: 1));
    yearRange = DateTimeRange(start: start, end: end);
  }

  void _loadData() {
    classes = StorageService.getAllClasses();
    entries = StorageService.getAllEntries();
    _computeStats();
    setState(() {});
  }

  void _computeStats() {
    stats = {};
    final currentSY = _getCurrentSchoolYearStart();
    // include each class
    for (final c in classes) {
      stats[c['id'].toString()] = {
        'count': 0,
        'sum': 0.0,
        'target': c['target'],
        'scoreLimit': c['scoreLimit'],
      };
    }
    // Uncategorized key
    stats['__uncat'] = {
      'count': 0,
      'sum': 0.0,
      'target': null,
      'scoreLimit': null,
    };

    for (final e in entries) {
      final sy = StorageService.getEntrySchoolYearStart(e, startMonth);
      if (sy == null || sy != currentSY) continue;
      final cid = e['classId'] ?? '__uncat';
      final key = cid == null || cid == '' ? '__uncat' : cid.toString();
      final sc = (e['score'] is num)
          ? (e['score'] as num).toDouble()
          : double.tryParse(e['score']?.toString() ?? '') ?? 0.0;
      final m = stats.putIfAbsent(
        key,
        () => {'count': 0, 'sum': 0.0, 'target': null, 'scoreLimit': null},
      );
      m['count'] = (m['count'] as int) + 1;
      m['sum'] = (m['sum'] as double) + sc;
    }
  }

  int _getCurrentSchoolYearStart() {
    final s = StorageService.getSettings();
    if (s['selectedSchoolYearStart'] != null) {
      return s['selectedSchoolYearStart'] as int;
    }
    final now = DateTime.now();
    return (now.month >= startMonth) ? now.year : now.year - 1;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('统计'), elevation: 0),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 学年范围卡片
            Card(
              elevation: 0,
              color: cs.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '当前学年',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${yearRange?.start.year}年${yearRange?.start.month}月 - ${yearRange?.end.year}年${yearRange?.end.month}月',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Icon(Icons.calendar_today, color: cs.primary, size: 24),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 统计标题
            Text(
              '学年统计',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // 统计列表
            Expanded(
              child: ListView(
                children: [
                  ...classes.map((c) {
                    final k = c['id'].toString();
                      final m =
                          stats[k] ??
                          {
                            'count': 0,
                            'sum': 0.0,
                            'target': c['target'],
                            'scoreLimit': c['scoreLimit'],
                          };
                    final met = (m['target'] != null)
                        ? (m['sum'] as double) >= (m['target'] as num)
                        : null;
                    final scoreLimitReached = (m['scoreLimit'] != null)
                        ? (m['sum'] as double) >= (m['scoreLimit'] as num)
                        : false;
                    final progress =
                        (m['target'] != null && (m['target'] as num) > 0)
                        ? ((m['sum'] as double) / (m['target'] as num)).clamp(
                            0.0,
                            1.0,
                          )
                        : 0.0;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Card(
                        elevation: 0,
                        color: scoreLimitReached
                            ? cs.errorContainer.withValues(alpha: 0.3)
                            : cs.surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      c['name'] ?? 'Unnamed',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  if (scoreLimitReached)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.error,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.warning_amber,
                                            color: cs.onError,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '已达上限',
                                            style: TextStyle(
                                              color: cs.onError,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else if (met != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: met
                                            ? cs.tertiaryContainer
                                            : cs.errorContainer,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            met
                                                ? Icons.check_circle
                                                : Icons.cancel,
                                            color: met
                                                ? cs.onTertiaryContainer
                                                : cs.onErrorContainer,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            met ? '达标' : '未达标',
                                            style: TextStyle(
                                              color: met
                                                  ? cs.onTertiaryContainer
                                                  : cs.onErrorContainer,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                                  Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  _StatItem(
                                    label: '条目数',
                                    value: '${m['count']}',
                                    cs: cs,
                                    context: context,
                                  ),
                                  _StatItem(
                                    label: '总分',
                                    value: (m['sum'] as double).toStringAsFixed(
                                      1,
                                    ),
                                    cs: cs,
                                    context: context,
                                  ),
                                  _StatItem(
                                    label: '目标',
                                    value: m['target']?.toString() ?? '-',
                                    cs: cs,
                                    context: context,
                                  ),
                                ],
                              ),
                              if (m['scoreLimit'] != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '分数上限: ${m['scoreLimit']}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: scoreLimitReached
                                                ? cs.error
                                                : cs.onSurfaceVariant,
                                            fontWeight: scoreLimitReached
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                    ),
                                    if (scoreLimitReached)
                                      Text(
                                        '(已达上限)',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: cs.error,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                  ],
                                ),
                              ],
                              if (m['target'] != null &&
                                  (m['target'] as num) > 0) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 8,
                                    backgroundColor: cs.surfaceContainerLow,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      progress >= 0.95
                                          ? cs.tertiary
                                          : cs.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  Builder(
                    builder: (_) {
                      final m =
                          stats['__uncat'] ??
                          {'count': 0, 'sum': 0.0};
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Card(
                          elevation: 0,
                          color: cs.surfaceContainerLow,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '未分类',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _StatItem(
                                      label: '条目数',
                                      value: '${m['count']}',
                                      cs: cs,
                                      context: context,
                                    ),
                                    _StatItem(
                                      label: '总分',
                                      value: (m['sum'] as double)
                                          .toStringAsFixed(1),
                                      cs: cs,
                                      context: context,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// M3 统计项组件
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme cs;
  final BuildContext context;

  const _StatItem({
    required this.label,
    required this.value,
    required this.cs,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: cs.primary,
          ),
        ),
      ],
    );
  }
}
