//
//  UploadPhotosAction.swift
//  ownCloud
//
//  Created by Felix Schwarz on 09.04.19.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2019, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
*/

import UIKit
import ownCloudSDK
import Photos
import MobileCoreServices

class UploadMediaAction: UploadBaseAction {
	override class var identifier : OCExtensionIdentifier? { return OCExtensionIdentifier("com.owncloud.action.uploadphotos") }
	override class var category : ActionCategory? { return .normal }
	override class var name : String { return "Upload from your photo library".localized }
	override class var locations : [OCExtensionLocationIdentifier]? { return [.folderAction] }

	private struct AssociatedKeys {
		static var actionKey = "action"
	}

	// MARK: - Action implementation
	override func run() {
		guard context.items.count == 1, context.items.first?.type == .collection, let viewController = context.viewController else {
			self.completed(with: NSError(ocError: .insufficientParameters))
			return
		}

		PHPhotoLibrary.requestAccess { (granted) in
			if granted {
				self.presentImageGalleryPicker()
			} else {
				let alert = UIAlertController.alertControllerForPhotoLibraryAuthorizationInSettings()
				viewController.present(alert, animated: true)
				self.completed()
			}
		}
	}

	private func presentImageGalleryPicker() {
		if let viewController = self.context.viewController {
			let photoAlbumViewController = PhotoAlbumTableViewController()
			photoAlbumViewController.selectionCallback = {(assets) in
				self.completed()

				guard let rootItem = self.context.items.first else { return }

				MediaUploadManager.shared.uploadQueue.uploadAssets(assets, with: self.core, at: rootItem, progressHandler: { (progress) in
					if progress.isFinished || progress.isCancelled {
						self.unpublish(progress: progress)
					} else {
						self.publish(progress: progress)
					}
				})
			}
			let navigationController = ThemeNavigationController(rootViewController: photoAlbumViewController)

			viewController.present(navigationController, animated: true)
		} else {
			self.completed(with: NSError(ocError: .internal))
		}
	}

	override class func iconForLocation(_ location: OCExtensionLocationIdentifier) -> UIImage? {
		if location == .folderAction {
			Theme.shared.add(tvgResourceFor: "image")
			return Theme.shared.image(for: "image", size: CGSize(width: 30.0, height: 30.0))!.withRenderingMode(.alwaysTemplate)
		}

		return nil
	}
}
