import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../repository/tennis_repository.dart';
import 'notification_helper.dart';

/// Top-level background message handler — runs on a fresh isolate when
/// a push arrives while the app is in the background or terminated.
/// MUST be top-level/static and annotated with @pragma('vm:entry-point')
/// so the Dart compiler does not strip it during tree-shaking. The
/// background isolate has no access to the main isolate's plugin state,
/// so we re-initialise Firebase here and call the public
/// `NotificationHelper` show methods (which themselves go through
/// flutter_local_notifications, which is isolate-safe).
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // NotificationHelper is a per-isolate singleton. The background
  // isolate has its own static instance with _initialized=false, so
  // Android 8+ notification channels don't exist here yet — calls to
  // _notificationsPlugin.show() would be silently dropped. Initialise
  // the channels in this isolate before rendering the notification.
  await NotificationHelper().initialize();
  final data = message.data;
  final type = data['type'] as String?;
  final idStr = data['id']?.toString() ?? '0';
  final id = int.tryParse(idStr) ?? 0;
  final title = data['title']?.toString() ?? '';
  final body = data['body']?.toString() ?? '';
  if (type == 'match') {
    await NotificationHelper().showRemoteMatch(
      id: id,
      title: title.isEmpty ? 'Trận đấu mới' : title,
      body: body,
      payload: 'match:$id',
    );
  } else if (type == 'season') {
    await NotificationHelper().showRemoteSeason(
      id: id,
      title: title.isEmpty ? 'Mùa giải mới' : title,
      body: body,
      payload: 'season:$id',
    );
  }
}

/// Wraps FCM lifecycle for the app. **SSE remains the in-foreground
/// real-time path** — this class deliberately does not duplicate
/// notifications while the app is open. See the dedup note in
/// `onMessage` below.
///
/// Roles:
///   * FCM background handler (terminated / background app) — the
///     only path that reaches the user when the OS has killed us.
///   * FCM foreground handler — suppresses the render when the app
///     is `resumed` because SSE is already firing local
///     notifications via `checkForNewMatches()`. When backgrounded,
///     SSE's `stopBackgroundSync()` has run, so FCM is the only
///     path left.
///   * tap-to-open, permission prompt, token registration, topic
///     subscription, token-rotation.
class PushNotifications {
  static final PushNotifications _instance = PushNotifications._internal();
  factory PushNotifications() => _instance;
  PushNotifications._internal();

  bool _initialized = false;
  // These StreamSubscriptions are held as fields only to keep them alive
  // for the lifetime of the app — the underlying streams are long-lived
  // (Firebase listens forever) and would be GC'd if we let the local
  // references go out of scope. The analyzer flags them as unused, which
  // is false: storing them IS the use.
  // ignore: unused_field
  StreamSubscription<RemoteMessage>? _foregroundSub;
  // ignore: unused_field
  StreamSubscription<RemoteMessage>? _openedSub;
  // ignore: unused_field
  StreamSubscription<String>? _tokenRefreshSub;

  /// Idempotent. Safe to call multiple times (e.g. from hot reload).
  Future<void> initialize(TennisRepository repo) async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    // Register the background handler BEFORE the first message arrives.
    // This is a no-op in the background isolate — the plugin just
    // remembers the function reference.
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    // Foreground dedup: when the app is `resumed`, the SSE loop in
    // TennisRepository is connected and will fire its own
    // `checkForNewMatches()` → local notification. To avoid showing
    // the same match twice (once from FCM, once from SSE), we
    // suppress the FCM-side render in this state. When the app is
    // backgrounded, `MainAppShell.didChangeAppLifecycleState` calls
    // `stopBackgroundSync()`, SSE is gone, and this handler is the
    // only path that shows the notification.
    _foregroundSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        debugPrint('[PushNotifications] foreground FCM suppressed — '
              'SSE owns the live path');
        return;
      }
      final data = message.data;
      final type = data['type'] as String?;
      final id = int.tryParse(data['id']?.toString() ?? '') ?? 0;
      final title = data['title']?.toString() ?? '';
      final body = data['body']?.toString() ?? '';
      if (type == 'match') {
        await NotificationHelper().showRemoteMatch(
          id: id,
          title: title.isEmpty ? 'Trận đấu mới' : title,
          body: body,
          payload: 'match:$id',
        );
      } else if (type == 'season') {
        await NotificationHelper().showRemoteSeason(
          id: id,
          title: title.isEmpty ? 'Mùa giải mới' : title,
          body: body,
          payload: 'season:$id',
        );
      }
    });

    // Tap-to-open: fires when the user taps a notification and the
    // app was backgrounded (not terminated). For cold-launch, see
    // `coldLaunchMessage` below.
    _openedSub = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // The payload is already captured by the existing
      // NotificationHelper tap handler (via flutter_local_notifications'
      // own tap callback) — this is a hook for future navigation.
      debugPrint('[PushNotifications] opened from background, '
            'data=${message.data}');
    });

    // Permission prompt: handled in NotificationHelper.requestPermissionOnFirstLaunch,
    // which gates the system dialog behind a Vietnamese in-app explanation
    // on the very first launch. Do NOT call FCM's requestPermission here —
    // it would pop the iOS system dialog immediately at startup with no
    // context (the user hasn't even seen the UI yet).
    // → see MainAppShell.initState → requestPermissionOnFirstLaunch.

    // Register / refresh the FCM token with the backend.
    await _registerToken(repo);

    // Re-register on token rotation (FCM rotates tokens periodically
    // and on app reinstall). The backend upserts on the token column.
    _tokenRefreshSub =
        FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('[PushNotifications] token rotated, re-registering');
      await repo.registerDevice(fcmToken: newToken, platform: defaultTargetPlatform.name);
    });

    // Subscribe to the global topics the server broadcasts to.
    // (See backend.md for the topic-based send strategy.)
    try {
      await FirebaseMessaging.instance.subscribeToTopic('all_matches');
      await FirebaseMessaging.instance.subscribeToTopic('all_seasons');
    } catch (e) {
      debugPrint('[PushNotifications] topic subscribe failed: $e');
    }

    // Cold-launch: if the app was launched by a tap on a notification,
    // FCM has the message available via getInitialMessage(). The
    // existing NotificationHelper tap handler will see the payload
    // via getNotificationAppLaunchDetails() for local notifications;
    // for remote pushes we expose the message here for callers that
    // want to navigate.
    final cold = await FirebaseMessaging.instance.getInitialMessage();
    if (cold != null) {
      debugPrint('[PushNotifications] cold-launched from push, '
            'data=${cold.data}');
    }
  }

  Future<void> _registerToken(TennisRepository repo) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final platform = defaultTargetPlatform.name; // 'android' or 'ios'
      final ok = await repo.registerDevice(fcmToken: token, platform: platform);
      debugPrint('[PushNotifications] registerDevice ok=$ok platform=$platform');
    } catch (e) {
      debugPrint('[PushNotifications] registerDevice failed: $e');
    }
  }

  /// Public re-register hook. Call this from the permission flow once
  /// the user has granted notifications — on iOS, `getToken()` returns
  /// null at first launch because the APNs token is only delivered
  /// after the user taps 'Allow' on the iOS system prompt. Without
  /// this re-register, iOS devices never appear in the backend's
  /// `devices` table until the next cold start.
  Future<void> refreshToken(TennisRepository repo) => _registerToken(repo);
}
