//
//  CV.swift
//  iOSExample
//
//  Created by Om More on 06/03/26.
//

import UIKit
enum Message {
  case Text(ChatMessageModel)
  case ChannelLink(ChatMessageModel, ParsedChannelLink)
  case DateSeparator(Date, isFirst: Bool)
  case LoadMore
}

typealias Messages = [Message]

protocol Deletage {
  func getSize(at: IndexPath, width: CGFloat) -> CGRect
  func getXOrigin(at: IndexPath, availableWidth: CGFloat, cellWidth: CGFloat) -> CGFloat
  func spacingAfterItem(at: IndexPath) -> CGFloat
}

