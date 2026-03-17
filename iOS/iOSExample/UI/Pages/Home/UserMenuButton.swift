import SwiftUI
import UIKit

struct UserMenuButton: UIViewRepresentable {
  let codename: String?
  let nickname: String?
  let onNicknameTap: () -> Void
  let onExport: () -> Void
  let onShareQR: () -> Void
  let onLogout: () -> Void
  private static let userIconSize = CGSize(width: 32, height: 32)

  private var displayName: String {
    if let nickname, !nickname.isEmpty {
      return nickname
    }
    return self.codename ?? "Loading..."
  }

  func makeUIView(context _: Context) -> UIButton {
    let button = UIButton(type: .system)
    button.showsMenuAsPrimaryAction = true
    button.tintColor = UIColor(named: "Haven")
    Self.updateUserIcon(for: button)
    button.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (button: UIButton, _) in
      Self.updateUserIcon(for: button)
    }

    return button
  }

  func updateUIView(_ button: UIButton, context _: Context) {
    let havenColor = UIColor(named: "Haven")

    // Nickname/Codename action - tappable to edit nickname
    let nameAction = UIAction(
      title: displayName
    ) { _ in
      self.onNicknameTap()
    }

    let nameMenu = UIMenu(options: .displayInline, children: [nameAction])
    nameMenu.preferredElementSize = .small

    let exportAction = UIAction(
      title: "Export",
      image: UIImage(systemName: "square.and.arrow.up")?.withTintColor(
        havenColor ?? .systemBlue, renderingMode: .alwaysOriginal
      )
    ) { _ in
      self.onExport()
    }

    let shareQRAction = UIAction(
      title: "QR Code",
      image: UIImage(systemName: "qrcode")?.withTintColor(
        havenColor ?? .systemBlue, renderingMode: .alwaysOriginal
      )
    ) { _ in
      self.onShareQR()
    }

    let logoutAction = UIAction(
      title: "Logout",
      image: UIImage(systemName: "rectangle.portrait.and.arrow.right"),
      attributes: .destructive
    ) { _ in
      self.onLogout()
    }

    let actionsMenu = UIMenu(
      options: .displayInline, children: [exportAction, shareQRAction, logoutAction]
    )

    button.menu = UIMenu(children: [nameMenu, actionsMenu])
  }

  private static func updateUserIcon(for button: UIButton) {
    let image = self.resizedImage(
      named: "user-icon",
      size: self.userIconSize,
      compatibleWith: button.traitCollection
    )
    button.setImage(image, for: .normal)
  }

  private static func resizedImage(
    named name: String,
    size: CGSize,
    compatibleWith traitCollection: UITraitCollection?
  ) -> UIImage? {
    guard let image = UIImage(named: name, in: .main, compatibleWith: traitCollection) else {
      return nil
    }
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: size))
    }.withRenderingMode(.alwaysOriginal)
  }
}

struct PlusMenuButton: UIViewRepresentable {
  let onJoinChannel: () -> Void
  let onCreateSpace: () -> Void
  let onScanQR: () -> Void

  func makeUIView(context _: Context) -> UIButton {
    let button = UIButton(type: .system)
    button.showsMenuAsPrimaryAction = true
    button.tintColor = .systemGray

    let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
    let image = UIImage(systemName: "plus", withConfiguration: config)?.withTintColor(
      .systemGray, renderingMode: .alwaysOriginal
    )
    button.setImage(image, for: .normal)

    return button
  }

  func updateUIView(_ button: UIButton, context _: Context) {
    let havenColor = UIColor(named: "Haven")

    let joinChannelAction = UIAction(
      title: "Join Channel",
      image: UIImage(systemName: "link")?.withTintColor(
        havenColor ?? .systemBlue, renderingMode: .alwaysOriginal
      )
    ) { _ in
      self.onJoinChannel()
    }

    let createSpaceAction = UIAction(
      title: "Create Space",
      image: UIImage(systemName: "plus.square")?.withTintColor(
        havenColor ?? .systemBlue, renderingMode: .alwaysOriginal
      )
    ) { _ in
      self.onCreateSpace()
    }

    let scanQRAction = UIAction(
      title: "Scan QR Code",
      image: UIImage(systemName: "qrcode.viewfinder")?.withTintColor(
        havenColor ?? .systemBlue, renderingMode: .alwaysOriginal
      )
    ) { _ in
      self.onScanQR()
    }

    button.menu = UIMenu(children: [joinChannelAction, createSpaceAction, scanQRAction])
  }
}
