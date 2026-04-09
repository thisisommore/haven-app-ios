//
//  Notifications.swift
//  iOSExample
//
//  Created by Om More on 21/03/26.
//

import Foundation
import Intents
import UIKit
import UserNotifications

final class Notifications: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  private weak var xxdk: XXDK?

  func set(xxdk: XXDK) {
    self.xxdk = xxdk
  }

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    let center = UNUserNotificationCenter.current()
    center.delegate = self

    center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
      AppLogger.app.info(
        "Push requestAuthorization granted=\(String(granted), privacy: .public) error=\(String(describing: error), privacy: .public)"
      )
    }

    DispatchQueue.main.async {
      application.registerForRemoteNotifications()
    }

    return true
  }

  func application(
    _: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    guard let xxdk = self.xxdk else {
      AppLogger.app.error("Push token received before setXxdk; dropping token")
      return
    }
    xxdk.addApnsToken(token)
  }

  func application(
    _: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    AppLogger.app.error(
      "Push didFailToRegisterForRemoteNotificationsWithError error=\(String(describing: error), privacy: .public)"
    )
  }

  func application(
    _: UIApplication,
    didReceiveRemoteNotification _: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    completionHandler(.noData)
  }

  func userNotificationCenter(
    _: UNUserNotificationCenter,
    willPresent _: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .badge, .sound, .list])
  }

  func userNotificationCenter(
    _: UNUserNotificationCenter,
    didReceive _: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    completionHandler()
  }

  func userNotificationCenter(
    _: UNUserNotificationCenter,
    openSettingsFor _: UNNotification?
  ) {}
}
