import SQLiteData
import SwiftUI

struct HomeView<T: XXDKP>: View {
  @State private var controller = HomePageController()

  @EnvironmentObject var xxdk: T
  @EnvironmentObject private var appStorage: AppStorage
  @EnvironmentObject private var navigation: AppNavigationPath
  @EnvironmentObject private var selectedChat: SelectedChat

  var body: some View {
    let chatList = List(selection: $selectedChat.chatId) {
      ForEach(self.controller.filteredChats) { chat in
        ChatRowView<T>(chat: chat)
          .tag(chat.id)
      }
    }
    .scrollContentBackground(.hidden)
    .background(Color.appBackground)

    let listHeader =
      chatList
        .searchable(
          text: self.$controller.searchText,
          placement: .navigationBarDrawer(displayMode: .automatic),
          prompt: "Search chats"
        )
        .tint(.gray.opacity(0.3))
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            HStack(spacing: 12) {
              UserMenuButton(
                codename: self.xxdk.codename,
                nickname: self.controller.currentNickname,
                onNicknameTap: {
                  self.controller.activeSheet = .nicknamePicker
                },
                onExport: {
                  self.controller.activeSheet = .exportIdentity
                },
                onShareQR: {
                  self.controller.openShareQRCode(xxdk: self.xxdk)
                },
                onLogout: {
                  self.controller.showLogoutAlert = true
                }
              )
              .frame(width: 28, height: 28)

              if self.xxdk.statusPercentage != 100 {
                Button(action: {
                  self.controller.showTooltip.toggle()
                }) {
                  ProgressView().tint(.haven)
                }
              }
            }
          }.hiddenSharedBackground()

          ToolbarItem(placement: .topBarTrailing) {
            PlusMenuButton(
              onJoinChannel: { self.controller.activeSheet = .newChat },
              onCreateSpace: { self.controller.activeSheet = .createSpace },
              onScanQR: { self.controller.activeSheet = .qrScanner }
            )
            .frame(width: 28, height: 28)
          }.hiddenSharedBackground()
        }

    let withSheet =
      listHeader
        .sheet(item: self.$controller.activeSheet) { sheet in
          switch sheet {
          case .newChat:
            NewChatSheet<T>()
          case .createSpace:
            CreateSpaceSheet<T>()
          case let .qrCode(data):
            QRCodeSheet(dmToken: data.token, pubKey: data.pubKey, codeset: data.codeset)
          case .qrScanner:
            QRScannerSheet(
              onCodeScanned: { code in
                self.controller.handleAddUser(
                  code: code
                )
              },
              onShowMyQR: {
                self.controller.scheduleShowMyQRAfterScannerDismissal(xxdk: self.xxdk)
              }
            )
          case .nicknamePicker:
            NicknamePickerSheet<T>(codename: self.xxdk.codename ?? "")
              .onDisappear {
                self.controller.loadCurrentNickname(xxdk: self.xxdk)
              }
          case .exportIdentity:
            if let codename = xxdk.codename {
              ExportIdentitySheet(
                xxdk: self.xxdk,
                onSuccess: { message in
                  self.controller.onExportSuccess(message: message)
                },
                codename: codename
              )
            }
          }
        }
        .alert("Logout", isPresented: self.$controller.showLogoutAlert) {
          Button("Cancel", role: .cancel) {}
          Button("Logout", role: .destructive) {
            self.controller.performLogout(
              xxdk: self.xxdk,
              appStorage: self.appStorage,
              navigation: self.navigation
            )
          }
        } message: {
          Text(
            "If you haven't backed up your identity, you will lose access to it permanently. Are you sure you want to logout?"
          )
        }

    return
      withSheet
        .overlay {
          if let toastMessage = self.controller.toastMessage {
            VStack {
              Spacer()
              HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.white)
                Text(toastMessage)
                  .font(.subheadline)
                  .fontWeight(.medium)
                  .foregroundColor(.white)
              }
              .padding(.horizontal, 20)
              .padding(.vertical, 14)
              .background(Color.haven)
              .cornerRadius(25)
              .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
              .padding(.bottom, 50)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
          }
        }
        .overlay {
          if self.controller.isLoggingOut {
            ZStack {
              Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {} // Block taps

              VStack(spacing: 16) {
                ProgressView()
                  .controlSize(.large)
                  .tint(.white)

                Text(self.xxdk.status)
                  .font(.headline)
                  .foregroundStyle(.white)
              }
              .padding(30)
              .background(.ultraThinMaterial)
              .cornerRadius(16)
            }
          }
        }
        .background(Color.appBackground)
        .onAppear {
          self.controller.onAppear(navigation: self.navigation, xxdk: self.xxdk)
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.large)
  }
}

#Preview {
  Mock {
    HomeView<XXDKMock>()
  }
}
