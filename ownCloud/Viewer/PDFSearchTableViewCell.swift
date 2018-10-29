//
//  PDFSearchTableViewCell.swift
//  ownCloud
//
//  Created by Michael Neuwert on 18.09.2018.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

import UIKit
import PDFKit

class PDFSearchTableViewCell: ThemeTableViewCell {

    var titleLabel = UILabel()
    var pageLabel = UILabel()

    static let identifier = "PDFSearchTableViewCell"

    fileprivate let layoutMargin: CGFloat = 20.0
    fileprivate let titleFontSize: CGFloat = 16
    fileprivate let pageFontSize: CGFloat = 15

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSubviewsAndConstraints()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupSubviewsAndConstraints()
    }

    fileprivate func setupSubviewsAndConstraints() {

        self.contentView.addSubview(titleLabel)
        self.contentView.addSubview(pageLabel)

        titleLabel.font = UIFont.systemFont(ofSize: titleFontSize, weight: UIFont.Weight.regular)
        titleLabel.adjustsFontSizeToFitWidth = false
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        pageLabel.font = UIFont.systemFont(ofSize: pageFontSize, weight: UIFont.Weight.light)
        pageLabel.textAlignment = .right
        pageLabel.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.topAnchor.constraint(equalTo: self.contentView.topAnchor).isActive = true
        titleLabel.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor).isActive = true
        titleLabel.leftAnchor.constraint(equalTo: self.contentView.leftAnchor, constant: layoutMargin).isActive = true

        pageLabel.topAnchor.constraint(equalTo: self.contentView.topAnchor).isActive = true
        pageLabel.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor).isActive = true
        pageLabel.rightAnchor.constraint(equalTo: self.contentView.rightAnchor, constant: -layoutMargin).isActive = true

        pageLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor).isActive = true

        titleLabel.setContentCompressionResistancePriority(UILayoutPriority.defaultLow, for: UILayoutConstraintAxis.horizontal)
        pageLabel.setContentCompressionResistancePriority(UILayoutPriority.defaultHigh, for: UILayoutConstraintAxis.horizontal)
    }

    // MARK: - Theme support
    override func applyThemeCollectionToCellContents(theme: Theme, collection: ThemeCollection) {
        let itemState = ThemeItemState(selected: self.isSelected)

        self.titleLabel.applyThemeCollection(collection, itemStyle: .title, itemState: itemState)
        self.pageLabel.applyThemeCollection(collection, itemStyle: .message, itemState: itemState)
    }

    func setup(with selection:PDFSelection) {
        // Create a copy to not modify original instance through extend() calls
        if let pdfSelection = selection.copy() as? PDFSelection {
            let matchStr = selection.string

            // Extend the selection around search match
            pdfSelection.extendForLineBoundaries()

            // Create attributed string where match substring is highlighted with bold font
            let range = (pdfSelection.string! as NSString).range(of: matchStr!, options: .caseInsensitive)
            let attrStr = NSMutableAttributedString(string: pdfSelection.string!)
            let boldFont = UIFont.systemFont(ofSize: titleFontSize, weight: UIFont.Weight.bold)
            attrStr.addAttribute(.font, value: boldFont, range: range)

            self.titleLabel.attributedText = attrStr
            self.pageLabel.text = "\(selection.pages.first?.label ?? "")"
        }
    }
}
