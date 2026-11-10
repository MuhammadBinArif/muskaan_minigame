import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game/data/records_repository.dart';
import '../../domain/player_smile_analytics.dart';

enum SmileAnalyticsRange { sevenDays, thirtyDays, ninetyDays, all }

extension SmileAnalyticsRangeLabel on SmileAnalyticsRange {
  String get label => switch (this) {
    SmileAnalyticsRange.sevenDays => '7 days',
    SmileAnalyticsRange.thirtyDays => '30 days',
    SmileAnalyticsRange.ninetyDays => '90 days',
    SmileAnalyticsRange.all => 'All',
  };

  Duration? get duration => switch (this) {
    SmileAnalyticsRange.sevenDays => const Duration(days: 7),
    SmileAnalyticsRange.thirtyDays => const Duration(days: 30),
    SmileAnalyticsRange.ninetyDays => const Duration(days: 90),
    SmileAnalyticsRange.all => null,
  };
}

class SmileHistoryQuery {
  const SmileHistoryQuery(this.playerId, this.range);
  final String playerId;
  final SmileAnalyticsRange range;

  @override
  bool operator ==(Object other) =>
      other is SmileHistoryQuery &&
      other.playerId == playerId &&
      other.range == range;

  @override
  int get hashCode => Object.hash(playerId, range);
}

final playerSmileHistoryProvider = FutureProvider.autoDispose
    .family<List<HistoricalSmileRound>, SmileHistoryQuery>((ref, query) {
      final duration = query.range.duration;
      final now = DateTime.now();
      return ref
          .watch(gameRecordsRepositoryProvider)
          .getPlayerSmileHistory(
            playerId: query.playerId,
            completedFrom: duration == null ? null : now.subtract(duration),
            completedThrough: now,
            order: SmileHistoryOrder.newestFirst,
            limit: 100,
          );
    });

const playerSmileAnalytics = PlayerSmileAnalytics();
