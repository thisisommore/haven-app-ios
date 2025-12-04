import SwiftUI
import UIKit

struct UserMenuButton: UIViewRepresentable {
    let codename: String?
    let onExport: () -> Void
    
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
        let codenameAction = UIAction(
            title: codename ?? "Loading...",
            attributes: .disabled
        ) { _ in }
        
        let exportAction = UIAction(
            title: "Export",
            image: UIImage(systemName: "square.and.arrow.up")
        ) { _ in
            onExport()
        }
        
        button.menu = UIMenu(children: [codenameAction, exportAction])
    }
}

