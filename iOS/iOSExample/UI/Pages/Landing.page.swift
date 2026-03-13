//
//  Landing.page.swift
//  iOSExample
//
//  Created by Om More on 17/12/25.
//

import SwiftUI

struct LandingPage<T: XXDKP>: View {
  @State private var moveUp: Bool = false
  @State private var showProgress: Bool = false
  @EnvironmentObject var xxdk: T
  @EnvironmentObject private var appStorage: AppStorage
  @State private var isLoadingDone = false
  var body: some View {
    VStack(spacing: 12) {
      VStack(alignment: .leading) {
        Text("XXNetwork").bold().font(.system(size: 22, design: .serif))
        Text("Haven App.").multilineTextAlignment(.leading).font(
          .system(size: 12, design: .serif)
        )
      }

      if self.showProgress && !self.isLoadingDone {
        HStack {
          ProgressView(value: self.xxdk.statusPercentage, total: 100).tint(
            .gray
          )
          .transition(.move(edge: .top).combined(with: .opacity))
          .onChange(of: self.xxdk.statusPercentage) { _, newValue in
            if newValue == 100 && self.appStorage.isSetupComplete && !self.isLoadingDone {
              self.isLoadingDone = true
            }
          }
        }.frame(width: 120)

        Text(self.xxdk.status).font(.system(size: 12)).foregroundStyle(
          .secondary
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .animation(.easeInOut(duration: 0.5), value: self.moveUp)
    .animation(
      .spring(response: 0.5, dampingFraction: 0.9),
      value: self.showProgress
    )
    .task {
      // 1) Hide progress for 1s (your comment says 2s, code had 1s)
      try? await Task.sleep(nanoseconds: 1_000_000_000)

      // 2) Move text up
      withAnimation(.easeInOut(duration: 2)) { self.moveUp = true }

      // 3) Slight delay, then reveal progress with a transition
      try? await Task.sleep(nanoseconds: 300_000_000)
      withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
        self.showProgress = true
      }
    }
    .onChange(of: self.showProgress) { _, newValue in
      if newValue && self.xxdk.statusPercentage == 100 && self.appStorage.isSetupComplete && !self.isLoadingDone {
        self.isLoadingDone = true
      }
    }
    .onChange(of: self.appStorage.isSetupComplete) { _, newValue in
      if newValue {
        self.isLoadingDone = true
      }
    }
  }
}

#Preview {
  return LandingPage<XXDKMock>().mock()
}
