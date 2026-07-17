//
//  MacUICommon.swift
//  haven
//
//  Small shared building blocks for the mac dialogs.
//

import SwiftUI

/// Settings-style row: label on the leading edge, control on the trailing
/// edge (LabeledContent only does this inside a Form on macOS).
struct MacSettingRow<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  init(_ title: String, @ViewBuilder content: () -> Content) {
    self.title = title
    self.content = content()
  }

  var body: some View {
    HStack {
      Text(self.title)
      Spacer()
      self.content
    }
  }
}
