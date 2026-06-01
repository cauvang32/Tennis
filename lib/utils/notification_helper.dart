import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/tennis_models.dart';

/// NotificationHelper — Handles local notifications for new matches and seasons on Android & iOS.
/// Ported from Kotlin NotificationHelper.kt & NotificationRepository.kt.
class NotificationHelper {
  static final NotificationHelper _instance = NotificationHelper._internal();
  factory NotificationHelper() => _instance;
  NotificationHelper._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isInitialized = false;

  static const String _matchChannelId = "tennis_match_channel";
  static const String _matchChannelName = "Match Updates";
  static const String _matchChannelDesc = "Notifications for new tennis matches";

  static const String _seasonChannelId = "tennis_season_channel";
  static const String _seasonChannelName = "Season Updates";
  static const String _seasonChannelDesc = "Notifications for new tennis seasons";

  static const int _matchNotificationIdBase = 1000;
  static const int _seasonNotificationIdBase = 2000;

  /// Initialize local notification channels
  Future<void> initialize() async {
    if (kIsWeb || _isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // App opened from notification
      },
    );

    // Create Android notification channels
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          _matchChannelId,
          _matchChannelName,
          description: _matchChannelDesc,
          importance: Importance.defaultImportance,
          enableLights: true,
          enableVibration: true,
        ),
      );

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          _seasonChannelId,
          _seasonChannelName,
          description: _seasonChannelDesc,
          importance: Importance.high,
          enableLights: true,
          enableVibration: true,
        ),
      );
    }

    _isInitialized = true;
  }

  /// Request permissions on Android 13+ and iOS
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final iosImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosImplementation != null) {
        final granted = await iosImplementation.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    }
    return true;
  }

  // ─── Last Seen Persistence (replicates NotificationRepository.kt) ──────────

  Future<int> getLastSeenMatchId() async {
    final val = await _storage.read(key: 'last_seen_match_id');
    return val != null ? (int.tryParse(val) ?? 0) : 0;
  }

  Future<int> getLastSeenSeasonId() async {
    final val = await _storage.read(key: 'last_seen_season_id');
    return val != null ? (int.tryParse(val) ?? 0) : 0;
  }

  Future<void> updateLastSeenMatchId(int matchId) async {
    final current = await getLastSeenMatchId();
    if (matchId > current) {
      await _storage.write(key: 'last_seen_match_id', value: matchId.toString());
    }
  }

  Future<void> updateLastSeenSeasonId(int seasonId) async {
    final current = await getLastSeenSeasonId();
    if (seasonId > current) {
      await _storage.write(key: 'last_seen_season_id', value: seasonId.toString());
    }
  }

  // ─── Notification Dispatch ──────────────────────────────────────────────────

  /// Check for new matches & show notification
  Future<void> checkForNewMatches(List<Match> matches) async {
    if (kIsWeb || matches.isEmpty) return;

    final lastSeen = await getLastSeenMatchId();
    final sortedMatches = List<Match>.from(matches)..sort((a, b) => a.id.compareTo(b.id));
    final currentMaxId = sortedMatches.last.id;

    if (lastSeen == 0) {
      // First time launch: Silently initialize last seen ID to prevent spamming notifications
      await updateLastSeenMatchId(currentMaxId);
      return;
    }

    int maxId = lastSeen;
    for (final match in sortedMatches) {
      if (match.id > lastSeen) {
        if (maxId == lastSeen) {
          await requestPermissions();
        }
        await _showNewMatchNotification(match);
        if (match.id > maxId) maxId = match.id;
      }
    }

    if (maxId > lastSeen) {
      await updateLastSeenMatchId(maxId);
    }
  }

  /// Check for new seasons & show notification
  Future<void> checkForNewSeasons(List<Season> seasons) async {
    if (kIsWeb || seasons.isEmpty) return;

    final lastSeen = await getLastSeenSeasonId();
    final sortedSeasons = List<Season>.from(seasons)..sort((a, b) => a.id.compareTo(b.id));
    final currentMaxId = sortedSeasons.last.id;

    if (lastSeen == 0) {
      // First time launch: Silently initialize
      await updateLastSeenSeasonId(currentMaxId);
      return;
    }

    int maxId = lastSeen;
    for (final season in sortedSeasons) {
      if (season.id > lastSeen) {
        if (maxId == lastSeen) {
          await requestPermissions();
        }
        await _showNewSeasonNotification(season);
        if (season.id > maxId) maxId = season.id;
      }
    }

    if (maxId > lastSeen) {
      await updateLastSeenSeasonId(maxId);
    }
  }

  Future<void> _showNewMatchNotification(Match match) async {
    const androidDetails = AndroidNotificationDetails(
      _matchChannelId,
      _matchChannelName,
      channelDescription: _matchChannelDesc,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final player1Desc = match.matchType == 'duo' && match.player2Name != null
        ? '${match.player1Name} & ${match.player2Name}'
        : (match.player1Name ?? 'Player A');

    final player2Desc = match.matchType == 'duo' && match.player4Name != null
        ? '${match.player3Name} & ${match.player4Name}'
        : (match.player3Name ?? 'Player B');

    final message = '$player1Desc vs $player2Desc (${match.team1Score} - ${match.team2Score})';

    await _notificationsPlugin.show(
      _matchNotificationIdBase + match.id,
      "⚽ Kết Quả Trận Đấu Mới!",
      message,
      details,
      payload: 'match:${match.id}',
    );
  }

  Future<void> _showNewSeasonNotification(Season season) async {
    const androidDetails = AndroidNotificationDetails(
      _seasonChannelId,
      _seasonChannelName,
      channelDescription: _seasonChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final dateRange = season.endDate != null
        ? 'Thời gian: ${season.startDate} đến ${season.endDate}'
        : 'Bắt đầu từ: ${season.startDate}';

    await _notificationsPlugin.show(
      _seasonNotificationIdBase + season.id,
      "📅 Giải Đấu Mới Khởi Tranh!",
      '${season.name}\n$dateRange',
      details,
      payload: 'season:${season.id}',
    );
  }
}
