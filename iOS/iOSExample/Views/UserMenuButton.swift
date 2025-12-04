import SwiftUI
import UIKit

struct UserMenuButton: UIViewRepresentable {
    let codename: String?
    let onExport: () -> Void
    let onShareQR: () -> Void
    let onLogout: () -> Void
    
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.showsMenuAsPrimaryAction = true
        button.tintColor = UIColor(named: "Haven")
        
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        let image = UIImage(systemName: "person.circle", withConfiguration: config)
        button.setImage(image, for: .normal)
        
        return button
    }
    
    func updateUIView(_ button: UIButton, context: Context) {
        let havenColor = UIColor(named: "Haven")
        
        let codenameAction = UIAction(
            title: codename ?? "Loading...",
            attributes: .disabled
        ) { _ in }
        
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
        
        button.menu = UIMenu(children: [codenameAction, exportAction, shareQRAction, logoutAction])
    }
}

struct PlusMenuButton: UIViewRepresentable {
    let onJoinChannel: () -> Void
    let onCreateSpace: () -> Void
    let onScanQR: () -> Void
    
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.showsMenuAsPrimaryAction = true
        button.tintColor = UIColor(named: "Haven")
        
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        let image = UIImage(systemName: "plus", withConfiguration: config)
        button.setImage(image, for: .normal)
        
        return button
    }
    
    func updateUIView(_ button: UIButton, context: Context) {
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
