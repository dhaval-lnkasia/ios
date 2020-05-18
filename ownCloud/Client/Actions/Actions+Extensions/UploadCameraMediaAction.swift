//
//  UploadCameraMediaAction.swift
//  ownCloud
//
//  Created by Michael Neuwert on 15.05.20.
//  Copyright © 2020 ownCloud GmbH. All rights reserved.
//

/*
* Copyright (C) 2020, ownCloud GmbH.
*
* This code is covered by the GNU Public License Version 3.
*
* For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
* You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
*
*/

import UIKit
import ownCloudSDK
import MobileCoreServices
import ImageIO
import AVFoundation

class CameraViewPresenter: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

	typealias CameraCaptureCompletionHandler = (_ imageURL:URL?, _ alternativeName:String?, _ deleteImportedFile:Bool) -> Void

	let imagePickerViewController = UIImagePickerController()
	var completionHandler: CameraCaptureCompletionHandler?

	func present(on viewController:UIViewController, with completion:@escaping CameraCaptureCompletionHandler) {
		self.completionHandler = completion

		guard UIImagePickerController.isSourceTypeAvailable(.camera),
			let cameraMediaTypes = UIImagePickerController.availableMediaTypes(for: .camera) else {
				return
		}

		imagePickerViewController.sourceType = .camera
		imagePickerViewController.mediaTypes = cameraMediaTypes
		imagePickerViewController.delegate = self
		imagePickerViewController.videoQuality = .typeHigh

		viewController.present(imagePickerViewController, animated: true)
	}

	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
		imagePickerViewController.dismiss(animated: true)

		var image: UIImage?
		var outputURL: URL?
		var alternativeName: String?
		var preferHEIC = false
		var preferMP4 = false
		var deleteImportedFile = true

		if let userDefaults = OCAppIdentity.shared.userDefaults {
			preferHEIC = !userDefaults.convertHeic
			preferMP4 = userDefaults.convertVideosToMP4
		}

		OnBackgroundQueue {
			defer {
				OnMainThread {
					self.completionHandler?(outputURL, alternativeName, deleteImportedFile)
				}
			}

			// Retrieve media type
			guard let type = info[.mediaType] as? String else { return }

			if type == String(kUTTypeImage) {
				// Retrieve UIImage
				image = info[.originalImage] as? UIImage

				let fileName = "camera_shot"
				let ext = preferHEIC ? "heic" : "jpg"
				let uti = preferHEIC ? AVFileType.heic as CFString : kUTTypeJPEG
				outputURL = URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent(fileName).appendingPathExtension(ext)

				guard let url = outputURL else { return }

				// For HEIC use AVFileType.heic as CFString instead of kUTTypeJPEG
				let destination = CGImageDestinationCreateWithURL(url as CFURL, uti, 1, nil)

				guard let dst = destination,
					let cgImage = image?.cgImage,
					let metaData = info[.mediaMetadata] as? NSDictionary else {
						outputURL = nil
						return
				}

				CGImageDestinationAddImage(dst, cgImage, metaData)

				if !CGImageDestinationFinalize(dst) {
					outputURL = nil
				}

			} else if type == String(kUTTypeMovie) {
				guard let videoURL = info[.mediaURL] as? URL else { return }

				let fileName = "video-clip"

				// Convert video to MPEG4 first
				if preferMP4 {
					outputURL = URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent(fileName).appendingPathExtension("mp4")
					guard let url = outputURL else { return }

					let avAsset = AVAsset(url: videoURL)
					if !avAsset.exportVideo(targetURL: url, type: .mp4) {
						outputURL = nil
					}

				} else {
					// Upload video as is
					deleteImportedFile = false
					outputURL = videoURL
					alternativeName = "\(fileName).\(videoURL.pathExtension)"
				}
			}
		}

	}
}

class UploadCameraMediaAction: UploadBaseAction, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

	override class var identifier : OCExtensionIdentifier? { return OCExtensionIdentifier("com.owncloud.action.upload.camera_media") }
	override class var category : ActionCategory? { return .normal }
	override class var name : String { return "Take photo or video".localized }
	override class var locations : [OCExtensionLocationIdentifier]? { return [.folderAction, .keyboardShortcut] }
	override class var keyCommand : String? { return "P" }
	override class var keyModifierFlags: UIKeyModifierFlags? { return [.command] }

	var cameraPresenter = CameraViewPresenter()

	// MARK: - Action implementation

	override class func iconForLocation(_ location: OCExtensionLocationIdentifier) -> UIImage? {
		if location == .folderAction {
			let image = UIImage(named: "camera")?.withRenderingMode(.alwaysTemplate)
			return image
		}

		return nil
	}

	override func run() {
		guard context.items.count == 1, let rootItem = context.items.first, rootItem.type == .collection, let viewController = context.viewController else {
			self.completed(with: NSError(ocError: .insufficientParameters))
			return
		}

		cameraPresenter.present(on: viewController) { (localImageURL, alternativeName, shallDelete) in
			if let url = localImageURL, let core = self.core {
				if let progress = url.upload(with: core, at: rootItem, alternativeName: alternativeName, placeholderHandler: { (_, _) in
					if shallDelete {
						try? FileManager.default.removeItem(at: url)
					}
				}) {
					self.publish(progress: progress)
				} else {
					Log.debug("Error setting up upload of \(Log.mask(url.lastPathComponent)) to \(Log.mask(rootItem.path))")
				}
			}
			self.completed()
		}
	}
}
