import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialise Firebase before GeneratedPluginRegistrant.register so
    // that the firebase_messaging plugin can read the config from
    // GoogleService-Info.plist during plugin registration.
    FirebaseApp.configure()

    // FCM delegate: handled on the Dart side via
    //   FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken)
    // in lib/utils/push_notifications.dart, so we do not set
    // Messaging.messaging().delegate here (it would require
    // AppDelegate to conform to MessagingDelegate, which the Dart
    // path makes unnecessary).

    // Register for remote (silent + alert) notifications so APNs can
    // hand off to FCM. iOS will then issue the user-permission prompt
    // the first time flutter_messaging requests it.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  // APNs device token → FCM registration token. firebase_messaging
  // listens for this on the swizzled didRegisterForRemoteNotifications
  // path automatically, but we forward explicitly so logs are clearer.
  override func application(_ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
}
