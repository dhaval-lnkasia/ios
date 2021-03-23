//
//  DocumentActionViewController.swift
//  ownCloud File Provider UI
//
//  Created by Matthias Hühne on 28.01.21.
//  Copyright © 2021 ownCloud GmbH. All rights reserved.
//

/*
* Copyright (C) 2021, ownCloud GmbH.
*
* This code is covered by the GNU Public License Version 3.
*
* For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
* You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
*
*/

import UIKit
import FileProviderUI
import ownCloudApp
import ownCloudAppShared
import ownCloudSDK

class DocumentActionViewController: FPUIActionExtensionViewController {

	private var coreConnectionStatusObservation : NSKeyValueObservation?
	weak var core: OCCore?
	var themeNavigationController : ThemeNavigationController?

	enum ActionExtensionType {
		case undefined, sharing, links
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		OCItem.registerIcons()
		ThemeStyle.registerDefaultStyles()
		Theme.shared.activeCollection = ThemeCollection(with: ThemeStyle.preferredStyle)
	}

	deinit {
		coreConnectionStatusObservation?.invalidate()
		coreConnectionStatusObservation = nil

		if let bookmark = core?.bookmark {
			OCCoreManager.shared.returnCore(for: bookmark, completionHandler: nil)
		}
	}

	override func prepare(forAction actionIdentifier: String, itemIdentifiers: [NSFileProviderItemIdentifier]) {

		guard let identifier = itemIdentifiers.first else {
			extensionContext.cancelRequest(withError: NSError(domain: FPUIErrorDomain, code: Int(FPUIExtensionErrorCode.userCancelled.rawValue), userInfo: nil))
			return
		}

		let collection = Theme.shared.activeCollection
		self.view.backgroundColor = collection.toolbarColors.backgroundColor

		themeNavigationController = ThemeNavigationController()
		if let themeNavigationController = themeNavigationController {
			view.addSubview(themeNavigationController.view)
			addChild(themeNavigationController)
		}

		showCancelLabel(with: "Connecting…".localized)

		var actionTypeLabel = ""
		var actionExtensionType : ActionExtensionType = .undefined
		if actionIdentifier == "com.owncloud.FileProviderUI.Share" {
			actionExtensionType = .sharing
			actionTypeLabel = "Share with user/group".localized
		} else if actionIdentifier == "com.owncloud.FileProviderUI.PublicLinks" {
			actionExtensionType = .links
			actionTypeLabel = "Share link".localized
		}

		OCCoreManager().requestCoreForBookmarkWithItem(withLocalID: identifier.rawValue, setup: nil) { [weak self] (error, core, databaseItem) in
			guard let self = self else { return }

			if let error = error {
				self.extensionContext.cancelRequest(withError: error)
			} else {
				self.core = core
				guard let item = databaseItem else { return }
				guard let core = self.core else { return }
				var triedConnecting = false

				self.coreConnectionStatusObservation = core.observe(\OCCore.connectionStatus, options: [.initial, .new]) { [weak self] (_, _) in
					guard let self = self else { return }

					OnMainThread {
						if core.connectionStatus == .online {
							self.coreConnectionStatusObservation?.invalidate()
							self.coreConnectionStatusObservation = nil

							if actionExtensionType == .sharing {
								let groupSharingController = GroupSharingTableViewController(core: core, item: item)
								groupSharingController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.dismissView))
								self.themeNavigationController?.viewControllers = [groupSharingController]
							} else if actionExtensionType == .links {
								let publicLinkController = PublicLinkTableViewController(core: core, item: item)
								publicLinkController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.dismissView))
								self.themeNavigationController?.viewControllers = [publicLinkController]
							}
						} else if core.connectionStatus == .connecting {
							triedConnecting = true
							self.showCancelLabel(with: "Connecting…".localized)
						} else if core.connectionStatus == .offline || core.connectionStatus == .unavailable {
							// Display error if `.connecting` isn't reached within 2 seconds
							OnMainThread(after: 2) {
								if !triedConnecting {
									self.showCancelLabel(with: String(format: "%@ is not available, when this account is offline. Please open the app and log into your account before you can do this action.".localized, actionTypeLabel))
								}
							}

							// Display error if `.connecting` has already been reached
							if triedConnecting {
								self.showCancelLabel(with: String(format: "%@ is not available, when this account is offline. Please open the app and log into your account before you can do this action.".localized, actionTypeLabel))
							}
						} else if actionExtensionType == .links, core.connection.capabilities?.sharingAPIEnabled == false, core.connection.capabilities?.publicSharingEnabled == false, item.isShareable == false {
							self.showCancelLabel(with: String(format: "%@ is not available for this item.".localized, actionTypeLabel))
						} else if actionExtensionType == .sharing, core.connection.capabilities?.sharingAPIEnabled == false {
							self.showCancelLabel(with: String(format: "%@ is not available for this item.".localized, actionTypeLabel))
						}
					}
				}
			}
		}
	}

	override func prepare(forError error: Error) {
		if AppLockManager.supportedOnDevice {
			AppLockManager.shared.passwordViewHostViewController = self
			AppLockManager.shared.cancelAction = { [weak self] in
				self?.extensionContext.cancelRequest(withError: NSError(domain: FPUIErrorDomain, code: Int(FPUIExtensionErrorCode.userCancelled.rawValue), userInfo: nil))
			}
			AppLockManager.shared.successAction = { [weak self] in
				self?.extensionContext.completeRequest()
			}

			AppLockManager.shared.showLockscreenIfNeeded()
		} else {
			showCancelLabel(with: "Passcode protection is not supported on this device.\nPlease disable passcode lock in the app settings.".localized)
		}
	}

	func showCancelLabel(with message: String) {
		OnMainThread {
			if let currentController = self.themeNavigationController?.viewControllers.first as? CancelLabelViewController {
				currentController.updateCancelLabels(with: message)
			} else {
				let cancelLabelViewController = UIStoryboard.init(name: "MainInterface", bundle: nil).instantiateViewController(withIdentifier: "CancelLabelViewController") as! CancelLabelViewController
				cancelLabelViewController.updateCancelLabels(with: message)
				self.themeNavigationController?.viewControllers = [cancelLabelViewController]
			}
		}
	}

	@objc func dismissView() {
		self.dismiss(animated: true) {
			self.extensionContext.completeRequest()
		}
	}
}
