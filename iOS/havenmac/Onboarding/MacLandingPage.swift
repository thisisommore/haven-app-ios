//
//  MacLandingPage.swift
//  haven
//
//  Brand splash shown while the first-time setup runs in the background.
//  Mirrors the iOS landing page, plus a hint when network setup drags on.
//

import Dependencies
import SwiftUI

struct MacLandingPage<T: XXDKP>: View {
  @EnvironmentObject var xxdk: T
  @Dependency(\.appStorage) private var appStorage

  @State private var showProgress = false
  @State private var showSlowHint = false

  var body: some View {
    VStack(spacing: 16) {
      VStack(alignment: .leading) {
        Text("XXNetwork").bold().font(.system(size: 22, design: .serif))
        Text("Haven App.").multilineTextAlignment(.leading).font(
          .system(size: 12, design: .serif)
        )
      }

      if self.showProgress {
        ProgressView()
          .controlSize(.small)
          .transition(.opacity)

        Text(self.xxdk.status.message)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .transition(.opacity)

        if self.showSlowHint {
          Text("Still trying to reach the xx network — this can take a few minutes on a slow connection.")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 320)
            .transition(.opacity)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .navigationBarBackButtonHidden()
    .animation(.easeInOut(duration: 0.5), value: self.showProgress)
    .animation(.easeInOut(duration: 0.5), value: self.showSlowHint)
    .task {
      try? await Task.sleep(nanoseconds: 1_000_000_000)
      withAnimation { self.showProgress = true }

      // If setup is still running after a while, reassure the user.
      try? await Task.sleep(nanoseconds: 60_000_000_000)
      if !self.appStorage.isSetupComplete {
        withAnimation { self.showSlowHint = true }
      }
    }
  }
}

#Preview {
  Mock {
    MacLandingPage<XXDKMock>()
  }
}
