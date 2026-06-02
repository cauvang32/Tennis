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

  // Set by initialize() (Android via getNotificationAppLaunchDetails, iOS via
  // _onBackgroundTap) if the app was cold-launched from a notification tap.
  // Consumed by consumeColdLaunchPayload() from the first screen that mounts.
  String? _coldLaunchPayload;

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

    // Cannot use `const` here: iosSettings takes a function reference
    // (onDidReceiveBackgroundNotificationResponse) which is not const.
    final androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Note: onDidReceiveBackgroundNotificationResponse is a parameter of
    // initialize() itself (not of DarwinInitializationSettings). It runs on
    // a background isolate, so the function MUST be @pragma('vm:entry-point')
    // static — see _onBackgroundTap below.
    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundTap,
    );

    // Android cold-launch detection. On iOS the same is reported via
    // _onBackgroundTap above (registered before the system delivers the
    // response, so the payload is captured even on a cold launch).
    final launchDetails = await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _coldLaunchPayload = launchDetails!.notificationResponse?.payload;
      debugPrint('[NotificationHelper] cold-launched from notification, '
                 'payload=$_coldLaunchPayload');
    }

    // Create Android notification channels
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          _matchChannelId,
          _matchChannelName,
          description: _matchChannelDesc,
          // high = shows as a heads-up notification on lock screen.
          // defaultImportance only refreshes the tray silently.
          importance: Importance.high,
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

  /// Returns the payload of a notification that launched the app cold, or
  /// null if the app was launched normally. The caller should call this
  /// exactly once from the first screen that mounts — it clears the value
  /// after returning so it isn't re-handled on rebuilds.
  String? consumeColdLaunchPayload() {
    final p = _coldLaunchPayload;
    _coldLaunchPayload = null;
    return p;
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
      importance: Importance.high,
      priority: Priority.high,
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
      id: _matchNotificationIdBase + match.id,
      title: "⚽ Kết Quả Trận Đấu Mới!",
      body: message,
      notificationDetails: details,
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
      id: _seasonNotificationIdBase + season.id,
      title: "📅 Giải Đấu Mới Khởi Tranh!",
      body: '${season.name}\n$dateRange',
      notificationDetails: details,
      payload: 'season:${season.id}',
    );
  }

  // ─── Notification Tap Callbacks ─────────────────────────────────────────────

  /// Fires when the user taps a notification while the app is in the
  /// foreground (or after the app has been launched/resumed by the tap).
  void _onNotificationTapped(NotificationResponse details) {
    final payload = details.payload;
    if (payload == null) return;
    debugPrint('[NotificationHelper] notification tapped, payload=$payload');
    // Future: navigate to the match/season based on payload prefix.
  }

  /// iOS-only. Fires when the user taps a notification that launched the
  /// app from a terminated or background state. Runs on a *background
  /// isolate* (different VM context), so it MUST be a top-level/static
  /// function and MUST be annotated with @pragma('vm:entry-point') so the
  /// Dart compiler does not strip it during tree-shaking. Instance state
  /// (including `_coldLaunchPayload`) is not accessible from here — the
  /// foreground path in initialize() recovers the same payload via
  /// getNotificationAppLaunchDetails().
  @pragma('vm:entry-point')
  static void _onBackgroundTap(NotificationResponse details) {
    debugPrint('[NotificationHelper] iOS cold-launch tap, '
               'payload=${details.payload}');
  }
}
