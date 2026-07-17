//
//  MacCodenamePage.swift
//  haven
//
//  Codename picker, redesigned for the Mac: a bordered list with radio-style
//  selection and native footer buttons instead of the phone card layout.
//  Logic mirrors the shared iOS `CodenameGeneratorView`.
//

import SwiftUI

struct MacCodenamePage<T: XXDKP>: View {
  @EnvironmentObject var xxdk: T
  @EnvironmentObject var navigation: AppNavigationPath

  @State private var codenames: [Codename] = []
  @State private var selectedCodename: Codename?
  @State private var isGenerating = false
  @State private var generatedIdentities: [GeneratedIdentity] = []
  @State private var showTooltip = false

  private let colors: [Color] = [
    .blue, .green, .haven, .purple, .pink, .red, .cyan, .mint, .indigo, .teal,
  ]

  private func generateCodenames() {
    self.isGenerating = true

    withAnimation(.easeOut(duration: 0.3)) {
      self.selectedCodename = nil
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      let newGeneratedIdentities = self.xxdk.generateIdentities(amountOfIdentities: 10)
      self.generatedIdentities = newGeneratedIdentities

      withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
        if newGeneratedIdentities.isEmpty {
          AppLogger.identity.error("No identities generated")
        } else {
          self.codenames = newGeneratedIdentities.enumerated().map { index, identity in
            let color = self.colors[index % self.colors.count]
            return Codename(text: identity.codename, color: color)
          }
        }
        self.isGenerating = false
      }
    }
  }

  private func claimCodename() {
    guard let selected = selectedCodename else { return }

    guard let identity = generatedIdentities.first(where: { $0.codename == selected.text })
    else {
      AppLogger.identity.error(
        "Could not find identity for codename: \(selected.text, privacy: .public)"
      )
      return
    }

    Task {
      await self.xxdk.setupClients(privateIdentity: identity.privateIdentity) {
        do {
          try self.xxdk.savePrivateIdentity(privateIdentity: identity.privateIdentity)
        } catch {
          fatalError("failed to save private identity in cmix ekv: \(error.localizedDescription)")
        }
      }
    }
    self.navigation.path.append(Destination.landing)
  }

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      VStack(alignment: .leading, spacing: 18) {
        HStack(alignment: .firstTextBaseline) {
          Text("Find your Codename")
            .font(.largeTitle)
            .fontWeight(.bold)

          Button {
            self.showTooltip.toggle()
          } label: {
            Image(systemName: "info.circle")
              .foregroundColor(.secondary)
          }
          .buttonStyle(.plain)
          .popover(isPresented: self.$showTooltip, arrowEdge: .bottom) {
            Text(
              "Codenames are generated on your computer by you. No servers or databases are involved at all. Your Codename is your personally owned anonymous identity shared across every Haven Chat you join. It is private and it can never be traced back to you."
            )
            .font(Font.caption)
            .padding(16)
            .frame(width: 280)
          }
        }

        Text("Pick one of the codenames generated on this Mac. It will be your public identity in Haven chats.")
          .font(.callout)
          .foregroundStyle(.secondary)

        VStack(spacing: 0) {
          ForEach(self.codenames) { codename in
            let isSelected = self.selectedCodename?.id == codename.id
            Button {
              withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                self.selectedCodename = codename
              }
            } label: {
              HStack(spacing: 12) {
                Circle()
                  .fill(codename.color)
                  .frame(width: 8, height: 8)

                Text(codename.text)
                  .font(.system(size: 14, design: .monospaced))
                  .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.haven)
                    .transition(.scale.combined(with: .opacity))
                }
              }
              .padding(.horizontal, 14)
              .padding(.vertical, 11)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(isSelected ? Color.haven.opacity(0.10) : Color.clear)

            if codename.id != self.codenames.last?.id {
              Divider().padding(.leading, 34)
            }
          }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
          if self.isGenerating {
            RoundedRectangle(cornerRadius: 10)
              .fill(.regularMaterial)
            ProgressView()
          }
        }

        HStack(spacing: 12) {
          Button {
            self.generateCodenames()
          } label: {
            Label("Generate New Set", systemImage: "arrow.clockwise")
              .frame(maxWidth: .infinity)
          }
          .controlSize(.large)
          .disabled(self.isGenerating)

          Button {
            self.claimCodename()
          } label: {
            Label("Claim Codename", systemImage: "checkmark")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          .controlSize(.large)
          .tint(.haven)
          .disabled(self.selectedCodename == nil || self.isGenerating)
          .keyboardShortcut(.defaultAction)
        }
      }
      .frame(width: 460)

      Spacer()
      Spacer()
    }
    .frame(maxWidth: .infinity)
    .navigationBarBackButtonHidden()
    .onAppear {
      Task.detached {
        await self.xxdk.startNetworkFollower()
      }
      if self.codenames.isEmpty && !self.isGenerating {
        self.generateCodenames()
      }
    }
  }
}
