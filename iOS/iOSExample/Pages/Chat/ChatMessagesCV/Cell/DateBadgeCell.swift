//
//  DateBadge.swift
//  iOSExample
//
//  Created by Om More on 10/03/26.
//

import UIKit

class DateBadgeCell: UICollectionViewCell {
    static let identifier = String(describing: DateBadgeCell.self)
    let container = UIView()
    let label = UILabel()
    static let paddingT: CGFloat = 22
    static let paddingB: CGFloat = 4
    static let innerPaddingX: CGFloat = 12
    static let innerPaddingY: CGFloat = 4
    static let innerPaddingXCal = innerPaddingX * 2
    static let innerPaddingYCal = innerPaddingY * 2

    override init(frame: CGRect) {
        super.init(frame: frame)
        makeUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static let textAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 10, weight: .medium)
    ]

    static func size(text: String, width: CGFloat) -> CGSize {
        let r = text.boundingRect(
            with: CGSize(width: width - innerPaddingXCal, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: Self.textAttributes,
            context: nil
        )

        let calculatedWidth = ceil(r.width) + innerPaddingXCal
        let calculatedHeight = ceil(r.height) + paddingB + paddingT + innerPaddingYCal

        return CGSize(width: calculatedWidth, height: calculatedHeight)
    }
}

extension DateBadgeCell {
    func makeUI() {
        contentView.addSubview(container)
        container.addSubview(label)

        container.backgroundColor = .tertiarySystemFill
        container.layer.cornerRadius = 10
        container.layer.masksToBounds = true

        container.snp.makeConstraints {
            $0.centerX.equalTo(contentView)
            $0.top.equalTo(contentView).offset(Self.paddingT)
            $0.bottom.equalTo(contentView).offset(-Self.paddingB)
        }

        label.snp.makeConstraints {
            $0.leading.equalTo(container).offset(Self.innerPaddingX)
            $0.trailing.equalTo(container).offset(-Self.innerPaddingX)
            $0.top.equalTo(container).offset(Self.innerPaddingY)
            $0.bottom.equalTo(container).offset(-Self.innerPaddingY)
        }

        label.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        label.textColor = .secondaryLabel
        label.text = "10 AM 2002"
        label.numberOfLines = 1
        label.textAlignment = .center
    }
}
