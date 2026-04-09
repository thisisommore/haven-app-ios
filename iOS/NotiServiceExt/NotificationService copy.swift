//
//  NotificationService copy.swift
//  NotiServiceExt
//
//  Created by Om More on 30/03/26.
//

import HavenCore
import Intents
import os
import SQLiteData
import UIKit
import UserNotifications

private let notificationDataUserInfoKey = "notificationData"

final class NotificationService: UNNotificationServiceExtension {
  private var contentHandler: ((UNNotificationContent) -> Void)?

  override init() {
    prepareDependencies {
      $0.defaultDatabase = try! appDatabase(migrate: false)
    }
  }

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler

    // get csv
    guard let csv = request.content.userInfo[notificationDataUserInfoKey] as? String else {
      self.deliverFallback()
      return
    }

    self.handleNotification(csv: csv)
  }

  func handleNotification(csv: String) {
    // get filters
    let filters = NotificationFilters.load()
    guard filters.dmFilter != nil || filters.channelFilter != nil else {
      self.deliverFallback()
      return
    }

    // get dm reports
    guard let dmReports = try? BindingsStatic.getDmNotificationReportsForMe(
      notificationFilterJSON: filters.dmFilter,
      notificationDataCSV: csv
    ) else {
      self.deliverFallback()
      return
    }

    // get channel reports
    guard let channelReports = try? BindingsStatic.getChannelNotificationReportsForMe(
      notificationFilterJSON: filters.channelFilter,
      notificationDataCSV: csv
    ) else {
      self.deliverFallback()
      return
    }

    var detailedReport: [RichMapping.NotificationItem] = []
    for i in dmReports {
      if let item = try? RichMapping.NotificationItem.from(report: i) {
        detailedReport.append(item)
      }
    }

    for i in channelReports {
      if let item = try? RichMapping.NotificationItem.from(report: i) {
        detailedReport.append(item)
      }
    }

    var chats: [String: RichMapping.Aggreate] = [:]

    for report in detailedReport {
      switch report.type {
      case .text:
        chats[report.chatName, default: .init()].textCount += 1
      case .reply:
        chats[report.chatName, default: .init()].replyCount += 1
      case .reaction:
        chats[report.chatName, default: .init()].reactionCount += 1
      default:
        continue
      }
    }

    let center = UNUserNotificationCenter.current()

    // Delivered (visible in notification center)
    center.getDeliveredNotifications { deliveredNoti in
      for c in chats {
        c.value.forType { msgType in
          let msgId = "\(c.key).\(msgType.rawValue)"
          let found = deliveredNoti.first {
            $0.request.content.userInfo["id"] as? String == msgId
          }
          let count = found?.request.content.userInfo["count"] as? UInt

          if let found, let count {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [found.request.identifier])
            chats[c.key]?.addCount(msgType, count: count)
          }
        }
      }
      let finalNoti: [UNNotificationContent] = chats.reduce([]) { acc, curr in
        acc + UNNotificationContent.from(aggreate: curr.value, sender: curr.key)
      }

      if let contentHandler = self.contentHandler, let first = finalNoti.first {
        self.deliverNotification([first], contentHandler: contentHandler)
      }

      self.deliverNotification(Array(finalNoti.dropFirst()), contentHandler: self.nextContentHandler)
    }
  }

  func nextContentHandler(_ content: UNNotificationContent) {
    let request = UNNotificationRequest(
      identifier: content.userInfo["id"] as! String,
      content: content,
      trigger: nil
    )
    UNUserNotificationCenter.current().add(request)
  }

  override func serviceExtensionTimeWillExpire() {
    self.deliverFallback()
  }

  func deliverNotification(_ rm: [UNNotificationContent], contentHandler: @escaping (UNNotificationContent) -> Void) {
    //

    for c in rm {
      // Push notification with uesr intent
      let x = Intent.mapToUserIntent(name: c.title)
      x.donate { error in
        if let error {
          AppLogger.messaging.error(
            "PushABCDOM failed to donate interaction: \(error.localizedDescription, privacy: .public)"
          )
          contentHandler(c)
          return
        }

        do {
          let updatedContent = try c.updating(from: x.intent as! INSendMessageIntent)
          AppLogger.messaging.info("PushABCDOM intent applied successfully")
          contentHandler(updatedContent)
        } catch {
          AppLogger.messaging.error(
            "PushABCDOM failed to apply intent: \(error.localizedDescription, privacy: .public)"
          )
          contentHandler(c)
        }
      }
    }
  }

  func deliverFallback() {
    let content = UNMutableNotificationContent()
    content.title = "Haven"
    content.subtitle = "You may have new messages"
    self.contentHandler?(content)
  }
}
