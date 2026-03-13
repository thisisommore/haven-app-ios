import SwiftUI
import UIKit

struct UserMenuButton: UIViewRepresentable {
    let codename: String?
    let nickname: String?
    let onNicknameTap: () -> Void
    let onExport: () -> Void
    let onShareQR: () -> Void
    let onLogout: () -> Void

    private var displayName: String {
        if let nickname, !nickname.isEmpty {
            return nickname
        }
        return codename ?? "Loading..."
    }

    func makeUIView(context _: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.showsMenuAsPrimaryAction = true
        button.tintColor = UIColor(named: "Haven")

        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        let image = UIImage(systemName: "person.circle", withConfiguration: config)
        button.setImage(image, for: .normal)

        return button
    }

    func updateUIView(_ button: UIButton, context _: Context) {
        let havenColor = UIColor(named: "Haven")

        // Nickname/Codename action - tappable to edit nickname
        let nameAction = UIAction(
            title: displayName
        ) { _ in
            onNicknameTap()
        }

        let nameMenu = UIMenu(options: .displayInline, children: [nameAction])
        nameMenu.preferredElementSize = .small

        let exportAction = UIAction(
            title: "Export",
            image: UIImage(systemName: "square.and.arrow.up")?.withTintColor(havenColor ?? .systemBlue, renderingMode: .alwaysOriginal)
        ) { _ in
            onExport()
        }

        let shareQRAction = UIAction(
            title: "QR Code",
            image: UIImage(systemName: "qrcode")?.withTintColor(havenColor ?? .systemBlue, renderingMode: .alwaysOriginal)
        ) { _ in
            onShareQR()
        }

        let logoutAction = UIAction(
            title: "Logout",
            image: UIImage(systemName: "rectangle.portrait.and.arrow.right"),
            attributes: .destructive
        ) { _ in
            onLogout()
        }

        let actionsMenu = UIMenu(options: .displayInline, children: [exportAction, shareQRAction, logoutAction])

        button.menu = UIMenu(children: [nameMenu, actionsMenu])
    }
}

struct PlusMenuButton: UIViewRepresentable {
    let onJoinChannel: () -> Void
    let onCreateSpace: () -> Void
    let onScanQR: () -> Void

    func makeUIView(context _: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.showsMenuAsPrimaryAction = true
        button.tintColor = UIColor(named: "Haven")

        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        let image = UIImage(systemName: "plus", withConfiguration: config)
        button.setImage(image, for: .normal)

        return button
    }

    func updateUIView(_ button: UIButton, context _: Context) {
        let havenColor = UIColor(named: "Haven")

        let joinChannelAction = UIAction(
            title: "Join Channel",
            image: UIImage(systemName: "link")?.withTintColor(havenColor ?? .systemBlue, renderingMode: .alwaysOriginal)
        ) { _ in
            onJoinChannel()
        }

        let createSpaceAction = UIAction(
            title: "Create Space",
            image: UIImage(systemName: "plus.square")?.withTintColor(havenColor ?? .systemBlue, renderingMode: .alwaysOriginal)
        ) { _ in
            onCreateSpace()
        }

        let scanQRAction = UIAction(
            title: "Scan QR Code",
            image: UIImage(systemName: "qrcode.viewfinder")?.withTintColor(havenColor ?? .systemBlue, renderingMode: .alwaysOriginal)
        ) { _ in
            onScanQR()
        }

        button.menu = UIMenu(children: [joinChannelAction, createSpaceAction, scanQRAction])
    }
}
