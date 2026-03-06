//
//  Controller+Gesture.swift
//  iOSExample
//
//  Created by Cursor on 06/03/26.
//

import UIKit

extension Controller: UIGestureRecognizerDelegate {
  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    shouldBeginGestureRecognizer(gestureRecognizer)
  }

  func gestureRecognizer(
    _ gestureRecognizer: UIGestureRecognizer,
    shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {
    shouldRecognizeSimultaneously(gestureRecognizer, with: otherGestureRecognizer)
  }
}
