//
//  MediaDisplayViewController.swift
//  ownCloud
//
//  Created by Michael Neuwert on 30.06.2019.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
* Copyright (C) 2018, ownCloud GmbH.
*
* This code is covered by the GNU Public License Version 3.
*
* For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
* You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
*
*/

import UIKit
import AVKit
import ownCloudSDK

class MediaDisplayViewController : DisplayViewController {

	private var playerStatusObservation: NSKeyValueObservation?
	private var playerItemStatusObservation: NSKeyValueObservation?
	private var playerItem: AVPlayerItem?
	private var player: AVPlayer?

	deinit {
		playerStatusObservation?.invalidate()
		playerItemStatusObservation?.invalidate()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		self.requiresLocalItemCopy = false
	}

	override func renderSpecificView() {
		if let sourceURL = source {

			let asset = AVURLAsset(url: sourceURL, options: self.httpAuthHeaders != nil ? ["AVURLAssetHTTPHeaderFieldsKey" : self.httpAuthHeaders!] : nil )
			playerItem = AVPlayerItem(asset: asset)

			player = AVPlayer(playerItem: playerItem)
			player?.allowsExternalPlayback = true
			let playerViewController = AVPlayerViewController()
			playerViewController.player = player

			addChild(playerViewController)
			self.view.addSubview(playerViewController.view)
			playerViewController.didMove(toParent: self)

			playerItemStatusObservation = playerItem?.observe(\AVPlayerItem.status, options: [.initial, .new], changeHandler: { [weak self] (item, _) in
				if item.status == .failed {
					self?.present(error: item.error)
				}
			})

			playerStatusObservation = player!.observe(\AVPlayer.status, options: [.initial, .new], changeHandler: { [weak self] (player, _) in
				if player.status == .readyToPlay {
					self?.player?.play()
				} else if player.status == .failed {
					self?.present(error: self?.player?.error)
				}
			})
		}
	}

	private func present(error:Error?) {
		guard let error = error else { return }

		OnMainThread { [weak self] in
			let alert = UIAlertController(with: "Error".localized, message: error.localizedDescription, okLabel: "OK".localized, action: {
				self?.navigationController?.popViewController(animated: true)
			})

			self?.parent?.present(alert, animated: true)
		}
	}
}

// MARK: - Display Extension.
extension MediaDisplayViewController: DisplayExtension {
	static var customMatcher: OCExtensionCustomContextMatcher? = { (context, defaultPriority) in
		do {
			if let mimeType = context.location?.identifier?.rawValue {
				let supportedFormatsRegex = try NSRegularExpression(pattern: "\\A((video/)|(audio/))",
																	options: .caseInsensitive)
				let matches = supportedFormatsRegex.numberOfMatches(in: mimeType, options: .reportCompletion, range: NSRange(location: 0, length: mimeType.count))

				if matches > 0 {
					return OCExtensionPriority.locationMatch
				}
			}

			return OCExtensionPriority.noMatch
		} catch {
			return OCExtensionPriority.noMatch
		}
	}
	static var displayExtensionIdentifier: String = "org.owncloud.media"
	static var supportedMimeTypes: [String]?
	static var features: [String : Any]? = [FeatureKeys.canEdit : false]
}
