//
//  DateBadge.swift
//  iOSExample
//
//  Created by Om More on 10/03/26.
//

import UIKit

class DateBadgeCell: UICollectionViewCell {
    static let identifier = String(describing: DateBadgeCell.self)
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
        .font: UIFont.systemFont(ofSize: 8)
    ]

    static func size(text: String, width: CGFloat) -> CGSize {
        let r = text.boundingRect(
            with: CGSize(width: width - paddingXCal, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: Self.textAttributes,
            context: nil
        )

        let width = ceil(r.width) + paddingXCal
        let height = r.height + paddingYCal

        // ceil to provide extra space since it might remove all the decimals which can result in smaller space
        return CGSize(width: width, height: height)
    }
}

extension DateBadgeCell {
    func makeUI() {
        contentView.addSubview(label)
        label.snp.makeConstraints {
            $0.center.equalTo(contentView)
        }
        label.text = "10 AM 2002"
        label.numberOfLines = 0
    }
}
