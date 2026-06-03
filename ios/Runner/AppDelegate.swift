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

    // Set FCM delegate so the SDK can route token-refresh callbacks.
    Messaging.messaging().delegate = self

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
