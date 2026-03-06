//
//  Controller+ScrollView.swift
//  iOSExample
//
//  Created by Cursor on 06/03/26.
//

import UIKit

extension Controller {
  func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
    handleScrollViewWillBeginDragging(scrollView)
  }

  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    handleScrollViewDidScroll(scrollView)
  }

  func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
    handleScrollViewDidEndScrollingAnimation(scrollView)
  }
}
