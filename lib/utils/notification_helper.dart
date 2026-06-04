import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

  // ─── First-Launch Permission Popup ─────────────────────────────────────────

  /// Show a custom in-app dialog (Vietnamese) explaining notifications,
  /// then request the system permission. **Auto-runs whenever the OS
  /// permission is missing** — not just on first launch. Safe to call
  /// from `initState` via `addPostFrameCallback`; the function
  /// short-circuits immediately if notification permission is already
  /// granted, and the `barrierDismissible: false` dialog cannot be
  /// dismissed without choosing, so no double-prompting within a
  /// single launch.
  ///
  /// Why this is here instead of relying on the OS prompt alone:
  ///   * On iOS, the FCM `requestPermission` call pops the system tray
  ///     *immediately* with no context — the user has not seen any UI
  ///     yet. Gating it behind a custom dialog gives the user a reason
  ///     to accept.
  ///   * On Android 13+, the runtime prompt is a single-use dialog;
  ///     the user can deny without understanding. An in-app prompt
  ///     first lets us show a localised explanation.
  /// Returns `true` if the user tapped 'Cho phép' (and the OS permission
  /// was then requested). Returns `false` for 'Để sau', for an already-
  /// granted permission, and for non-Android/iOS platforms.
  ///
  /// Callers should call [PushNotifications.refreshToken] when this
  /// returns `true` so that iOS devices whose APNs token is only
  /// delivered after the system prompt get persisted to the backend.
  Future<bool> requestPermissionOnFirstLaunch(BuildContext context) async {
    if (kIsWeb) return false;
    // FCM has no desktop implementation — the plugin throws
    // MissingPluginException on macOS/Linux/Windows. Skip the entire
    // dialog (and the doomed FCM request) on non-mobile platforms.
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }

    // Auto-ask only if the OS permission is actually missing. If the
    // user has already granted it (or it is permanently denied by the
    // OS), we skip the dialog. On Android 13+ "permanently denied"
    // manifests as `areNotificationsEnabled() == false` even after
    // we call requestPermission — in that case the dialog still
    // appears as a reminder that the user can re-enable in Settings.
    if (await _hasNotificationPermission()) return false;
    if (!context.mounted) return false;

    final confirmed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            icon: Icon(Icons.notifications_active, color: Theme.of(ctx).colorScheme.primary, size: 40),
            title: const Text('Bật thông báo?',
                style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text(
              'Chúng tôi sẽ gửi thông báo khi có trận đấu mới hoặc mùa giải mới.\n\n'
              'Bạn có thể tắt thông báo bất cứ lúc nào trong Cài đặt hệ thống.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Để sau'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Cho phép'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return false;

    // Local notification permission (Android 13+ system dialog, iOS no-op
    // because FCM handles the OS-level prompt for remote notifications).
    await requestPermissions();
    // FCM remote notification permission (iOS system dialog, Android no-op
    // because the FCM plugin auto-registers the token without it).
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('[NotificationHelper] FCM requestPermission failed: $e');
    }
    return true;
  }

  /// Check the actual OS-level notification permission. Returns true
  /// if the app is currently allowed to post notifications.
  Future<bool> _hasNotificationPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      // On Android 12 and below, this always returns true (no runtime
      // permission needed). On 13+, it reflects POST_NOTIFICATIONS.
      return await androidImpl?.areNotificationsEnabled() ?? true;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      // `provisional` is granted-but-quiet — we still treat it as
      // "has permission" so we don't re-prompt.
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    }
    return true;
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

  // ─── Remote (FCM) Notification Rendering ──────────────────────────────────

  /// Render a "new match" notification from a remote push payload.
  /// Called by the FCM background handler (in a background isolate) and
  /// by the foreground `onMessage` listener in push_notifications.dart.
  /// The server is expected to supply the title and body — we just
  /// render them through the existing match channel so the UX matches
  /// local notifications exactly.
  Future<void> showRemoteMatch({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (kIsWeb) return;
    // Dedup against the SSE path. If the user was in the app when the
    // event happened, the SSE pipeline already fired a local
    // notification and persisted `last_seen >= id`. Without this check
    // the FCM background handler would re-render the same match the
    // moment it arrives, producing two system-tray entries for the
    // same event.
    final lastSeen = await getLastSeenMatchId();
    if (id <= lastSeen) {
      debugPrint('[NotificationHelper] FCM match $id <= last_seen $lastSeen, skipping (SSE already showed)');
      return;
    }
    const androidDetails = AndroidNotificationDetails(
      _matchChannelId,
      _matchChannelName,
      channelDescription: _matchChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _notificationsPlugin.show(
      id: _matchNotificationIdBase + id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
    // Persist last-seen so that when the user resumes the app the SSE
    // check in fetchInitData doesn't fire a duplicate of the same match.
    await updateLastSeenMatchId(id);
  }

  /// Render a "new season" notification from a remote push payload.
  /// See [showRemoteMatch] for context.
  Future<void> showRemoteSeason({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (kIsWeb) return;
    // Dedup against the SSE path — same logic as showRemoteMatch.
    // If the SSE path already showed this season, last_seen >= id and
    // we skip; otherwise we show and update last_seen for next time.
    final lastSeen = await getLastSeenSeasonId();
    if (id <= lastSeen) {
      debugPrint('[NotificationHelper] FCM season $id <= last_seen $lastSeen, skipping (SSE already showed)');
      return;
    }
    const androidDetails = AndroidNotificationDetails(
      _seasonChannelId,
      _seasonChannelName,
      channelDescription: _seasonChannelDesc,
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _notificationsPlugin.show(
      id: _seasonNotificationIdBase + id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
    // See note in showRemoteMatch — prevents the SSE path from
    // double-notifying when the user reopens the app.
    await updateLastSeenSeasonId(id);
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
