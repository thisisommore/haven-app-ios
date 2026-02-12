import SwiftUI
import UIKit

struct NewChatBackSwipeControl: UIViewControllerRepresentable {
    let isDisabled: Bool

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.isDisabled = isDisabled
        return controller
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.isDisabled = isDisabled
        uiViewController.apply()
    }

    final class Controller: UIViewController {
        var isDisabled = false
        private var previousEnabledState: Bool?

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            apply()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            restore()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            if parent == nil {
                restore()
            }
        }

        func apply() {
            guard let recognizer = navigationController?.interactivePopGestureRecognizer else { return }
            if previousEnabledState == nil {
                previousEnabledState = recognizer.isEnabled
            }
            recognizer.isEnabled = !isDisabled
        }

        private func restore() {
            guard let recognizer = navigationController?.interactivePopGestureRecognizer else { return }
            if let previousEnabledState {
                recognizer.isEnabled = previousEnabledState
            } else {
                recognizer.isEnabled = true
            }
        }
    }
}
