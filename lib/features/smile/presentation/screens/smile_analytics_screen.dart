import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../game/data/records_repository.dart';
import '../../../profile/data/player_profile_repository.dart';
import '../../../results/presentation/screens/results_screen.dart';
import '../../domain/player_smile_analytics.dart';
import '../providers/smile_analytics_provider.dart';

enum SmileChartMetric { average, peak }

class SmileChartPoint {
  const SmileChartPoint({required this.round, required this.value});
  final HistoricalSmileRound round;
  final double value;
}

List<SmileChartPoint> buildSmileChartSeries(
  Iterable<HistoricalSmileRound> rounds,
  SmileChartMetric metric,
) {
  final sorted =
      rounds.where((round) => round.isValid).toList()..sort((a, b) {
        final time = a.completedAt.compareTo(b.completedAt);
        return time != 0 ? time : a.resultId.compareTo(b.resultId);
      });
  return sorted
      .map(
        (round) => SmileChartPoint(
          round: round,
          value:
              metric == SmileChartMetric.average
                  ? round.averageIntensity
                  : round.peakIntensity,
        ),
      )
      .toList(growable: false);
}

class SmileAnalyticsScreen extends ConsumerStatefulWidget {
  const SmileAnalyticsScreen({super.key});

  @override
  ConsumerState<SmileAnalyticsScreen> createState() =>
      _SmileAnalyticsScreenState();
}

class _SmileAnalyticsScreenState extends ConsumerState<SmileAnalyticsScreen> {
  SmileAnalyticsRange _range = SmileAnalyticsRange.thirtyDays;
  SmileChartMetric _metric = SmileChartMetric.average;
  int? _selectedPoint;
  final List<HistoricalSmileRound> _comparison = [];

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(playerProfileProvider);
    final profile = profileState.asData?.value;
    if (profile == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF100C18),
        body: Center(
          child:
              profileState.isLoading
                  ? const CircularProgressIndicator()
                  : const Text(
                    'Player profile unavailable.',
                    style: TextStyle(color: Colors.white),
                  ),
        ),
      );
    }
    final query = SmileHistoryQuery(profile.id, _range);
    final history = ref.watch(playerSmileHistoryProvider(query));
    return Scaffold(
      backgroundColor: const Color(0xFF100C18),
      appBar: AppBar(
        backgroundColor: const Color(0xFF191426),
        foregroundColor: Colors.white,
        title: const Text('Smile Analytics'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed:
              () => context.canPop() ? context.pop() : context.go('/profile'),
          icon: const Icon(Icons.chevron_left),
        ),
      ),
      body: SafeArea(
        child: history.when(
          loading:
              () => const Center(
                key: Key('analytics-loading'),
                child: CircularProgressIndicator(),
              ),
          error:
              (_, _) => _AnalyticsMessage(
                key: const Key('analytics-error'),
                icon: Icons.cloud_off_outlined,
                title: 'Analytics could not be loaded',
                detail: 'Your saved results were preserved. Try again.',
                action: TextButton(
                  onPressed:
                      () => ref.invalidate(playerSmileHistoryProvider(query)),
                  child: const Text('Retry'),
                ),
              ),
          data:
              (rounds) => RefreshIndicator(
                onRefresh: () async {
                  await ref.refresh(playerSmileHistoryProvider(query).future);
                },
                child: ListView(
                  key: ValueKey('analytics-${profile.id}-${_range.name}'),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _PlayerOverview(
                      avatar: profile.avatar,
                      name: profile.displayName,
                      summary: playerSmileAnalytics.progress(rounds),
                    ),
                    const SizedBox(height: 16),
                    _rangePicker(),
                    const SizedBox(height: 16),
                    if (rounds.isEmpty)
                      const _AnalyticsMessage(
                        key: Key('analytics-empty'),
                        icon: Icons.insights_outlined,
                        title: 'No measured rounds yet',
                        detail:
                            'Complete a calibrated Smile round to begin your private on-device history.',
                      )
                    else ...[
                      _chart(rounds),
                      const SizedBox(height: 16),
                      _personalBests(rounds),
                      const SizedBox(height: 16),
                      _comparisonCard(),
                      const SizedBox(height: 16),
                      _history(rounds, profile.id),
                    ],
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _rangePicker() => Semantics(
    label: 'Analytics date range',
    child: Wrap(
      spacing: 8,
      children: [
        for (final range in SmileAnalyticsRange.values)
          ChoiceChip(
            key: Key('range-${range.name}'),
            label: Text(range.label),
            selected: _range == range,
            onSelected: (_) {
              setState(() {
                _range = range;
                _selectedPoint = null;
                _comparison.clear();
              });
            },
          ),
      ],
    ),
  );

  Widget _chart(List<HistoricalSmileRound> rounds) {
    final points = buildSmileChartSeries(rounds, _metric);
    final selected =
        _selectedPoint != null && _selectedPoint! < points.length
            ? points[_selectedPoint!]
            : null;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Smile intensity progress', style: _titleStyle),
          const SizedBox(height: 10),
          SegmentedButton<SmileChartMetric>(
            segments: const [
              ButtonSegment(
                value: SmileChartMetric.average,
                label: Text('Average'),
              ),
              ButtonSegment(value: SmileChartMetric.peak, label: Text('Peak')),
            ],
            selected: {_metric},
            onSelectionChanged: (selection) {
              setState(() {
                _metric = selection.single;
                _selectedPoint = null;
              });
            },
          ),
          const SizedBox(height: 16),
          Semantics(
            label:
                '${_metric == SmileChartMetric.average ? 'Average' : 'Peak'} Smile Intensity chart, 0 to 100 percent, ${points.length} measured rounds',
            child: SizedBox(
              height: 190,
              child: LayoutBuilder(
                builder:
                    (context, constraints) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        if (points.isEmpty) return;
                        final usable = math.max(1.0, constraints.maxWidth - 54);
                        final fraction = ((details.localPosition.dx - 38) /
                                usable)
                            .clamp(0.0, 1.0);
                        setState(
                          () =>
                              _selectedPoint =
                                  (fraction * (points.length - 1)).round(),
                        );
                      },
                      child: CustomPaint(
                        key: const Key('smile-history-chart'),
                        painter: _SmileChartPainter(
                          points: points,
                          selectedIndex: _selectedPoint,
                        ),
                      ),
                    ),
              ),
            ),
          ),
          if (selected != null)
            Text(
              '${_date(selected.round.completedAt)} · ${selected.value.toStringAsFixed(1)}% · Round ${selected.round.resultId}',
              key: const Key('chart-tooltip'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFFD45C)),
            ),
        ],
      ),
    );
  }

  Widget _personalBests(List<HistoricalSmileRound> rounds) {
    final bests = playerSmileAnalytics.personalBests(rounds)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Personal bests', style: _titleStyle),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _BestCard(
                label: 'Highest Average',
                value: bests.highestAverageIntensity,
                round: bests.bestByAverage,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BestCard(
                label: 'Highest Peak',
                value: bests.highestPeakIntensity,
                round: bests.bestByPeak,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _comparisonCard() {
    final comparison =
        _comparison.length == 2
            ? playerSmileAnalytics.compare(_comparison[0], _comparison[1])
            : null;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Compare rounds', style: _titleStyle),
          const SizedBox(height: 6),
          Text(
            comparison == null
                ? 'Select two rounds below. The second is compared with the first.'
                : 'Round ${comparison.firstResultId} → Round ${comparison.secondResultId}',
          ),
          if (comparison != null) ...[
            const SizedBox(height: 10),
            _comparisonRow(
              'Average Smile Intensity',
              comparison.averageIntensity,
            ),
            _comparisonRow('Peak Smile Intensity', comparison.peakIntensity),
            _comparisonRow(
              'Valid Observations',
              comparison.validObservationCount,
            ),
            _comparisonRow(
              'Observed Span (ms)',
              comparison.observedSpanMilliseconds,
            ),
          ],
        ],
      ),
    );
  }

  Widget _comparisonRow<T extends num>(
    String label,
    SmileMetricComparison<T> value,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          '${value.first} → ${value.second} · ${_direction(value.direction)}',
        ),
      ],
    ),
  );

  Widget _history(List<HistoricalSmileRound> rounds, String playerId) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Recent measured rounds', style: _titleStyle),
      const SizedBox(height: 8),
      for (final round in rounds)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _RoundCard(
            round: round,
            selected: _comparison.contains(round),
            onCompare: () {
              setState(() {
                if (_comparison.contains(round)) {
                  _comparison.remove(round);
                } else {
                  if (_comparison.length == 2) _comparison.removeAt(0);
                  _comparison.add(round);
                }
              });
            },
            onOpen: () => _openResult(round, playerId),
          ),
        ),
      const Text(
        'Showing up to 100 measured rounds in this date range.',
        style: TextStyle(color: Color(0xFF9A92AA), fontSize: 12),
      ),
    ],
  );

  Future<void> _openResult(HistoricalSmileRound round, String playerId) async {
    final record = await ref
        .read(gameRecordsRepositoryProvider)
        .getSessionById(round.resultId);
    if (!mounted) return;
    final activePlayer = ref.read(playerProfileProvider).asData?.value.id;
    if (record == null ||
        record.playerId != playerId ||
        activePlayer != playerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That result is unavailable.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResultsScreen(gameRecord: record),
      ),
    );
  }
}

const _titleStyle = TextStyle(
  color: Color(0xFFFFF4E6),
  fontSize: 17,
  fontWeight: FontWeight.w800,
);

class _PlayerOverview extends StatelessWidget {
  const _PlayerOverview({
    required this.avatar,
    required this.name,
    required this.summary,
  });
  final String avatar;
  final String name;
  final SmileProgressSummary? summary;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 30,
              child: Text(avatar, style: const TextStyle(fontSize: 30)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: _titleStyle,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text('Private on-device smile progress'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _OverviewValue(
              'Measured Rounds',
              summary?.eligibleRoundCount.toString() ?? '—',
            ),
            _OverviewValue(
              'Average of Rounds',
              summary == null
                  ? '—'
                  : '${summary!.averageOfRoundAverages.toStringAsFixed(1)}%',
            ),
            _OverviewValue(
              'Highest Peak',
              summary == null
                  ? '—'
                  : '${summary!.highestPeakIntensity.toStringAsFixed(1)}%',
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          summary == null
              ? 'Most recent measured round: unavailable'
              : 'Most recent measured round: ${_date(summary!.mostRecentRound.completedAt)} · Round ${summary!.mostRecentRound.resultId}',
        ),
      ],
    ),
  );
}

class _OverviewValue extends StatelessWidget {
  const _OverviewValue(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFFFD45C),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    ),
  );
}

class _BestCard extends StatelessWidget {
  const _BestCard({
    required this.label,
    required this.value,
    required this.round,
  });
  final String label;
  final double value;
  final HistoricalSmileRound round;
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Text(
          '${value.toStringAsFixed(1)}%',
          style: const TextStyle(
            color: Color(0xFFFFD45C),
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          '${_date(round.completedAt)} · Round ${round.resultId}',
          style: const TextStyle(fontSize: 11),
        ),
      ],
    ),
  );
}

class _RoundCard extends StatelessWidget {
  const _RoundCard({
    required this.round,
    required this.selected,
    required this.onCompare,
    required this.onOpen,
  });
  final HistoricalSmileRound round;
  final bool selected;
  final VoidCallback onCompare;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_date(round.completedAt)} · Round ${round.resultId}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Checkbox(
              value: selected,
              onChanged: (_) => onCompare(),
              semanticLabel: 'Select round ${round.resultId} for comparison',
            ),
          ],
        ),
        Text(
          'Average Smile Intensity: ${round.averageIntensity.toStringAsFixed(1)}%',
        ),
        Text(
          'Peak Smile Intensity: ${round.peakIntensity.toStringAsFixed(1)}%',
        ),
        Text('Valid Observations: ${round.validObservationCount}'),
        Text(
          'Observed Span: ${_span(round.observedSpan)} between first and last accepted samples',
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onOpen,
            child: const Text('Open result'),
          ),
        ),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF25213A),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF403A58)),
    ),
    child: DefaultTextStyle(
      style: const TextStyle(color: Color(0xFFD4CDDF), height: 1.35),
      child: child,
    ),
  );
}

class _AnalyticsMessage extends StatelessWidget {
  const _AnalyticsMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });
  final IconData icon;
  final String title;
  final String detail;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: const Color(0xFFFFD45C)),
          const SizedBox(height: 12),
          Text(title, style: _titleStyle, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFBDB5C9)),
          ),
          if (action != null) action!,
        ],
      ),
    ),
  );
}

class _SmileChartPainter extends CustomPainter {
  const _SmileChartPainter({required this.points, required this.selectedIndex});
  final List<SmileChartPoint> points;
  final int? selectedIndex;
  @override
  void paint(Canvas canvas, Size size) {
    const left = 38.0;
    const top = 10.0;
    const bottom = 28.0;
    final width = math.max(1.0, size.width - left - 16);
    final height = math.max(1.0, size.height - top - bottom);
    final grid =
        Paint()
          ..color = const Color(0xFF514A67)
          ..strokeWidth = 1;
    final labelStyle = const TextStyle(color: Color(0xFFAAA1BA), fontSize: 10);
    for (final value in [0, 25, 50, 75, 100]) {
      final y = top + height * (1 - value / 100);
      canvas.drawLine(Offset(left, y), Offset(left + width, y), grid);
      final text = TextPainter(
        text: TextSpan(text: '$value', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(left - text.width - 6, y - text.height / 2));
    }
    if (points.isEmpty) return;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final x =
          left +
          (points.length == 1
              ? width / 2
              : width * index / (points.length - 1));
      final y = top + height * (1 - points[index].value / 100);
      index == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFF8252)
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    for (var index = 0; index < points.length; index++) {
      final x =
          left +
          (points.length == 1
              ? width / 2
              : width * index / (points.length - 1));
      final y = top + height * (1 - points[index].value / 100);
      canvas.drawCircle(
        Offset(x, y),
        index == selectedIndex ? 6 : 4,
        Paint()
          ..color =
              index == selectedIndex
                  ? const Color(0xFFFFD45C)
                  : const Color(0xFFFF8252),
      );
    }
    final first = TextPainter(
      text: TextSpan(
        text: _shortDate(points.first.round.completedAt),
        style: labelStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    first.paint(canvas, Offset(left, size.height - bottom + 8));
    if (points.length > 1) {
      final last = TextPainter(
        text: TextSpan(
          text: _shortDate(points.last.round.completedAt),
          style: labelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      last.paint(
        canvas,
        Offset(left + width - last.width, size.height - bottom + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SmileChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.selectedIndex != selectedIndex;
}

String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';
String _shortDate(DateTime value) => '${value.day}/${value.month}';
String _span(Duration value) =>
    value.inMilliseconds < 1000
        ? '${value.inMilliseconds} ms'
        : '${(value.inMilliseconds / 1000).toStringAsFixed(1)} s';
String _direction(SmileComparisonDirection value) => switch (value) {
  SmileComparisonDirection.higher => 'Higher',
  SmileComparisonDirection.lower => 'Lower',
  SmileComparisonDirection.equal => 'Unchanged',
};
