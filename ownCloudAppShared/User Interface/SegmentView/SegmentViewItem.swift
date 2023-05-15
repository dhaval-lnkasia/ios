//
//  SegmentViewItem.swift
//  ownCloudAppShared
//
//  Created by Felix Schwarz on 29.09.22.
//  Copyright © 2022 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2022, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

import UIKit

public class SegmentViewItem: NSObject {
	public enum CornerStyle {
		case sharp
		case round(points: CGFloat)
	}

	public enum Style {
		case plain
		case label
		case chevron
		case token
	}

	public enum Line: Int {
		case singleLine
		case primary
		case secondary
	}

	open weak var segmentView: SegmentView?

	open var style: Style
	open var icon: UIImage?
	open var title: String? {
		didSet {
			_view = nil
		}
	}
	open var titleTextStyle: UIFont.TextStyle?
	open var titleTextWeight: UIFont.Weight?
	open var titleLinebreakMode: NSLineBreakMode?

	open var representedObject: AnyObject?
	open weak var weakRepresentedObject: AnyObject?

	open var iconTitleSpacing: CGFloat = 2
	open var insets: NSDirectionalEdgeInsets = NSDirectionalEdgeInsets(top: 3, leading: 5, bottom: 3, trailing: 5)
	open var cornerStyle: CornerStyle?
	open var alpha: CGFloat = 1.0

	open var lines: [Line]? //!< Optional Lines that can be used to separate content into multiple lines (used f.ex. for grid cell layouts to use a single array for single line and multi line views)

	open var embedView: UIView?

	open var gestureRecognizers: [UIGestureRecognizer]?

	var _view: UIView?
	open var view: UIView? {
		if _view == nil {
			_view = SegmentViewItemView(with: self)
			_view?.translatesAutoresizingMaskIntoConstraints = false

			if let gestureRecognizers {
				_view?.gestureRecognizers = gestureRecognizers
			}
		}
		return _view
	}

	public init(with icon: UIImage? = nil, title: String? = nil, style: Style = .plain, titleTextStyle: UIFont.TextStyle? = nil, titleTextWeight: UIFont.Weight? = nil, linebreakMode: NSLineBreakMode? = nil, lines: [Line]? = nil, view: UIView? = nil, representedObject: AnyObject? = nil, weakRepresentedObject: AnyObject? = nil, gestureRecognizers: [UIGestureRecognizer]? = nil) {
		self.style = style

		super.init()

		self.icon = icon
		self.title = title
		self.titleTextStyle = titleTextStyle
		self.titleTextWeight = titleTextWeight
		self.titleLinebreakMode = linebreakMode
		self.lines = lines
		self.embedView = view
		self.representedObject = representedObject
		self.weakRepresentedObject = weakRepresentedObject
		self.gestureRecognizers = gestureRecognizers
	}
}

extension [SegmentViewItem] {
	func filtered(for lines: [SegmentViewItem.Line], includeUntagged: Bool) -> [SegmentViewItem] {
		return filter({ item in
			if let itemLines = item.lines {
				for line in lines {
					if itemLines.contains(line) {
						return true
					}
				}

				return false
			}

			return includeUntagged
		})
	}
}
