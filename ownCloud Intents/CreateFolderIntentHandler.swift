//
//  CreateFolderIntentHandler.swift
//  ownCloudAppShared
//
//  Created by Matthias Hühne on 31.07.19.
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
import Intents
import ownCloudSDK
import ownCloudAppShared

@available(iOS 13.0, *)
public class CreateFolderIntentHandler: NSObject, CreateFolderIntentHandling {

	public func handle(intent: CreateFolderIntent, completion: @escaping (CreateFolderIntentResponse) -> Void) {

		guard IntentSettings.shared.isEnabled else {
			completion(CreateFolderIntentResponse(code: .disabled, userActivity: nil))
			return
		}

		guard !AppLockManager.isPassCodeEnabled else {
			completion(CreateFolderIntentResponse(code: .authenticationRequired, userActivity: nil))
			return
		}

		guard let path = intent.path?.pathRepresentation, let uuid = intent.account?.uuid, let name = intent.name else {
			completion(CreateFolderIntentResponse(code: .failure, userActivity: nil))
			return
		}

		guard let bookmark = OCBookmarkManager.shared.bookmark(for: uuid) else {
			completion(CreateFolderIntentResponse(code: .accountFailure, userActivity: nil))
			return
		}

		guard IntentSettings.shared.isLicensedFor(bookmark: bookmark) else {
			completion(CreateFolderIntentResponse(code: .unlicensed, userActivity: nil))
			return
		}

		OCItemTracker().item(for: bookmark, at: path) { (error, core, item) in
			if error == nil, let targetItem = item {
				let folderPath = String(format: "%@%@", path, name)
				// Check, if the folder already exists in the given path
				OCItemTracker().item(for: bookmark, at: folderPath) { (error, core, folderPathItem) in
					if error == nil, folderPathItem == nil, let core = core {

						let progress = core.createFolder(name, inside: targetItem, options: nil, placeholderCompletionHandler: { (error, item) in
							if error != nil {
								completion(CreateFolderIntentResponse(code: .failure, userActivity: nil))
							} else {
								completion(CreateFolderIntentResponse.success(path: item?.path ?? ""))
							}
						})

						if progress == nil {
							completion(CreateFolderIntentResponse(code: .failure, userActivity: nil))
						}
					} else if core != nil {
						completion(CreateFolderIntentResponse(code: .folderExistsFailure, userActivity: nil))
					} else {
						completion(CreateFolderIntentResponse(code: .failure, userActivity: nil))
					}
				}
			} else if core != nil {
				completion(CreateFolderIntentResponse(code: .pathFailure, userActivity: nil))
			} else {
				completion(CreateFolderIntentResponse(code: .failure, userActivity: nil))
			}
		}
	}

	public func resolveName(for intent: CreateFolderIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
		if let name = intent.name {
			completion(INStringResolutionResult.success(with: name))
		} else {
			completion(INStringResolutionResult.needsValue())
		}
	}

	public func resolveAccount(for intent: CreateFolderIntent, with completion: @escaping (AccountResolutionResult) -> Void) {
		if let account = intent.account {
			completion(AccountResolutionResult.success(with: account))
		} else {
			completion(AccountResolutionResult.needsValue())
		}
	}

	public func provideAccountOptions(for intent: CreateFolderIntent, with completion: @escaping ([Account]?, Error?) -> Void) {
		completion(OCBookmarkManager.shared.accountList, nil)
	}

	public func resolvePath(for intent: CreateFolderIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
		if let path = intent.path {
			completion(INStringResolutionResult.success(with: path))
		} else {
			completion(INStringResolutionResult.needsValue())
		}
	}
}

@available(iOS 13.0, *)
extension CreateFolderIntentResponse {

    public static func success(path: String) -> CreateFolderIntentResponse {
        let intentResponse = CreateFolderIntentResponse(code: .success, userActivity: nil)
        intentResponse.path = path
        return intentResponse
    }
}
