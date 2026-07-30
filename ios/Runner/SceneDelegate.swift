import Flutter
import UIKit
import UserNotifications

class SceneDelegate: FlutterSceneDelegate {
  // Must stay in sync with LaunchTapReader._tapKey in Dart
  // (the `flutter.` prefix is added by the shared_preferences iOS plugin).
  static let launchRouteKey = "flutter.bbtr_launch_destination"

  private static let deepLinkKeys = ["deep_link", "target", "url", "deeplink", "link"]
  private static let nestedContainers = ["payload", "data"]

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard
      let response = connectionOptions.notificationResponse,
      let destination = Self.extractDestination(
        from: response.notification.request.content.userInfo
      )
    else { return }

    stash(destination)

    #if DEBUG
    NSLog("[BB.TRAIL] captured notification destination")
    #endif
  }

  private func stash(_ destination: String) {
    let defaults = UserDefaults.standard
    defaults.set(destination, forKey: Self.launchRouteKey)
    defaults.synchronize()
  }

  private static func extractDestination(
    from payload: [AnyHashable: Any]
  ) -> String? {
    if let direct = firstNonEmpty(in: payload) { return direct }
    for container in nestedContainers {
      guard let nested = payload[container] as? [AnyHashable: Any] else { continue }
      if let value = firstNonEmpty(in: nested) { return value }
    }
    return nil
  }

  private static func firstNonEmpty(
    in dictionary: [AnyHashable: Any]
  ) -> String? {
    for candidate in deepLinkKeys {
      guard let value = dictionary[candidate] as? String else { continue }
      let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
      if !trimmed.isEmpty { return trimmed }
    }
    return nil
  }
}
