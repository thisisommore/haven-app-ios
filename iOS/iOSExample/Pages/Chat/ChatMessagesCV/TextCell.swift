//
//  TextCell.swift
//  iOSExample
//
//  Created by Om More on 07/03/26.
//

import SwiftUI
import UIKit

class TextCell: UICollectionViewCell {
    static let identifier = String(describing: TextCell.self)
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        makeUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static let textAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 17)
    ]

    static func size(text: String, width: CGFloat) -> CGSize {
        let r = text.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: Self.textAttributes,
            context: nil
        )

        // ceil to provide extra space since it might remove all the decimals which can result in smaller space
        return CGSize(width: ceil(r.width), height: ceil(r.height))
    }
}

extension TextCell {
    func makeUI() {
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = ""
        label.numberOfLines = 0
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            label.topAnchor.constraint(equalTo: contentView.topAnchor),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        contentView.backgroundColor = UIColor(Color.messageBubble)
    }
}
