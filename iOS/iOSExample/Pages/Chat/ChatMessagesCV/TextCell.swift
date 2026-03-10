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
    static let paddingY: CGFloat = 4
    static let paddingX: CGFloat = 8
    static let paddingYCal = paddingY * 2
    static let paddingXCal = paddingX * 2
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
            with: CGSize(width: width - paddingXCal, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: Self.textAttributes,
            context: nil
        )

        // ceil to provide extra space since it might remove all the decimals which can result in smaller space
        return CGSize(width: ceil(r.width) + paddingXCal, height: ceil(r.height) + paddingYCal)
    }
}

extension TextCell {
    func makeUI() {
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = ""
        label.numberOfLines = 0
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: Self.paddingX),
            label.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -Self.paddingX),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Self.paddingY),
            label.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor, constant: -Self.paddingY),
        ])

        contentView.backgroundColor = UIColor(Color.messageBubble)
        contentView.layer.cornerRadius = 16
    }
}
