//
//  ConfidentialContentView.swift
//  ownCloud
//
//  Created by Matthias Hühne on 09.12.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

import ownCloudSDK
import ownCloudApp

public class ConfidentialContentView: UIView, Themeable {
	
	var text: String = "Confidential Content" {
		didSet {
			setNeedsDisplay()
		}
	}
	var subtext: String = "Confidential Content" {
		didSet {
			setNeedsDisplay()
		}
	}
	var textColor: UIColor = Theme.shared.activeCollection.css.getColor(.stroke, selectors: [.confidentialLabel], for: nil) ?? .red {
		didSet {
			setNeedsDisplay()
		}
	}
	var subtitleTextColor: UIColor = Theme.shared.activeCollection.css.getColor(.stroke, selectors: [.confidentialSecondaryLabel], for: nil) ?? .red {
		didSet {
			setNeedsDisplay()
		}
	}
	var font: UIFont = UIFont.systemFont(ofSize: 14) {
		didSet {
			setNeedsDisplay()
		}
	}
	var subtitleFont: UIFont = UIFont.systemFont(ofSize: 8) {
		didSet {
			setNeedsDisplay()
		}
	}
	var angle: CGFloat = 45 {
		didSet {
			setNeedsDisplay()
		}
	}
	var columnSpacing: CGFloat = 50 {
		didSet {
			setNeedsDisplay()
		}
	}
	var lineSpacing: CGFloat = 40 {
		didSet {
			setNeedsDisplay()
		}
	}
	var marginY: CGFloat = 10 {
		didSet {
			setNeedsDisplay()
		}
	}

	private var drawn: Bool = false

	override init(frame: CGRect) {
		super.init(frame: frame)
		setupOrientationObserver()
		Theme.shared.register(client: self, applyImmediately: true)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		setupOrientationObserver()
	}

	deinit {
		Theme.shared.unregister(client: self)
		NotificationCenter.default.removeObserver(self)
	}

	private func setupOrientationObserver() {
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(handleOrientationChange),
			name: UIDevice.orientationDidChangeNotification,
			object: nil
		)
	}

	@objc private func handleOrientationChange() {
		drawn = false
		setNeedsDisplay()
	}

	public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
		for subview in subviews.reversed() {
			let subviewPoint = convert(point, to: subview)
			if let hitView = subview.hitTest(subviewPoint, with: event) {
				return hitView
			}
		}
		return nil // Allow touches to pass through
	}

	public override func draw(_ rect: CGRect) {
		guard ConfidentialManager.shared.markConfidentialViews, let context = UIGraphicsGetCurrentContext() else { return }

		drawn = true

		context.saveGState()

		let radians = angle * .pi / 180
		context.rotate(by: radians)

		let textAttributes: [NSAttributedString.Key: Any] = [
			.font: font,
			.foregroundColor: textColor
		]
		let subtextAttributes: [NSAttributedString.Key: Any] = [
			.font: font,
			.foregroundColor: textColor
		]

		let textSize = text.size(withAttributes: textAttributes)
		let subtextSize = subtext.size(withAttributes: subtextAttributes)

		let stepX = textSize.width + columnSpacing
		let stepY = textSize.height + lineSpacing

		let stepSubtextX = subtextSize.width + columnSpacing
		let stepSubTextY = subtextSize.height + lineSpacing

		let rotatedDiagonal = sqrt(rect.width * rect.width + rect.height * rect.height)

		let startX = -rotatedDiagonal
		let startY = -rotatedDiagonal + marginY
		let endX = rotatedDiagonal
		let endY = rotatedDiagonal - marginY

		var y = startY
		while y <= endY {
			var x = startX
			var col = 0
			while x <= endX {
				if col % 2 == 0 {
					text.draw(at: CGPoint(x: x, y: y), withAttributes: textAttributes)
					x += stepX
				} else {
					subtext.draw(at: CGPoint(x: x, y: y + (stepSubTextY / 2)), withAttributes: subtextAttributes)
					x += stepSubtextX
				}
				col += 1
			}
			y += stepY
		}

		context.restoreGState()

		if angle < 45.0 {
			let combinedText = "\(subtext) - \(text)"
			let combinedTextAttributes: [NSAttributedString.Key: Any] = [
				.font: subtitleFont,
				.foregroundColor: subtitleTextColor
			]
			let combinedTextSize = combinedText.size(withAttributes: combinedTextAttributes)

			var x = CGFloat(0)
			let subtextY = rect.height - combinedTextSize.height - 2
			while x < rect.width {
				combinedText.draw(at: CGPoint(x: x, y: subtextY), withAttributes: combinedTextAttributes)
				x += combinedTextSize.width + columnSpacing
			}
		}
	}

	public func applyThemeCollection(theme: Theme, collection: ThemeCollection, event: ThemeEvent) {
		if let color = collection.css.getColor(.stroke, selectors: [.confidentialLabel], for: nil) {
			textColor = color
		}
		if let color = collection.css.getColor(.stroke, selectors: [.confidentialSecondaryLabel], for: nil) {
			subtitleTextColor = color
		}

		drawn = false
		setNeedsDisplay()
	}
}

public extension UIView {

	func secureView(core: OCCore?) {
		let overlayView = ConfidentialContentView()
		overlayView.text = core?.bookmark.user?.emailAddress ?? "Confidential View"
		overlayView.subtext = core?.bookmark.userName ?? "Confidential View"
		overlayView.backgroundColor = .clear
		overlayView.translatesAutoresizingMaskIntoConstraints = false
		overlayView.angle = (self.frame.height <= 200) ? 10 : 45

		self.addSubview(overlayView)

		NSLayoutConstraint.activate([
			overlayView.topAnchor.constraint(equalTo: self.topAnchor),
			overlayView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
			overlayView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
			overlayView.trailingAnchor.constraint(equalTo: self.trailingAnchor)
		])
	}

	var withScreenshotProtection: UIView {
		if ConfidentialManager.shared.allowScreenshots {
			return self
		}

		let secureContainerView = SecureTextField().secureContainerView
		secureContainerView.embed(toFillWith: self)
		return secureContainerView
	}
}
