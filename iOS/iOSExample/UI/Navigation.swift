//
//  Navigation.swift
//  iOSExample
//
//  Created by Om More on 29/09/25.
//

import Foundation
import SwiftUI

extension Destination {
  @MainActor @ViewBuilder
  func _destinationView() -> some View {
    switch self {
    case .landing:
      LandingPage<XXDK>()

    case .home:
      HomeView<XXDK>()

    case .codenameGenerator:
      CodenameGeneratorView<XXDK>()

    case .password:
      PasswordCreationView<XXDK>()

    case let .chat(chatId):
      ChatView<XXDK>(chatId: chatId)

    case .logViewer:
      LogViewerUI()
    }
  }

  @MainActor
  func destinationView() -> some View {
    self._destinationView()
      // hidden since most components don't use this, for example new user flow
      // and chat page uses its own back button
      .navigationBarBackButtonHidden()
      .toolbarBackground(.ultraThinMaterial)
  }
}
