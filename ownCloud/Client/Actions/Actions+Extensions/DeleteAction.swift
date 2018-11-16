//
//  DeleteAction.swift
//  ownCloud
//
//  Created by Pablo Carrascal on 12/11/2018.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

import ownCloudSDK

class DeleteAction : Action {
	override class var identifier : OCExtensionIdentifier? { return OCExtensionIdentifier("com.owncloud.action.delete") }
	override class var category : ActionCategory? { return .destructive }
	override class var name : String? { return "Delete".localized }

	// MARK: - Extension matching
	override class func applicablePosition(forContext: ActionContext) -> ActionPosition {
		// Examine items in context
		return .last
	}

	// MARK: - Action implementation
	override func run() {
		guard context.items.count > 0, let viewController = context.viewController else {
			completionHandler?(NSError(ocError: .errorInsufficientParameters))
			return
		}

		let items = context.items

		let message: String
		if items.count > 1 {
			message = "Are you sure you want to delete this items from the server?".localized
		} else {
			message = "Are you sure you want to delete this item from the server?".localized
		}

		let name: String
		if items.count > 1 {
			name = "Multiple items".localized
		} else {
			name = items[0].name
		}

		let alertController = UIAlertController(
			with: name,
			message: message,
			destructiveLabel: "Delete".localized,
			preferredStyle: UIDevice.current.isIpad() ? UIAlertControllerStyle.alert : UIAlertControllerStyle.actionSheet,
			destructiveAction: {
				for item in items {
					if let progress = self.core.delete(item, requireMatch: true, resultHandler: { (error, _, _, _) in
						if error != nil {
							Log.log("Error \(String(describing: error)) deleting \(String(describing: item.path))")
							self.completionHandler?(error!)
						}
					}) {
						self.progressHandler?(progress)
					}
				}

				self.completionHandler?(nil)
		})

		viewController.present(alertController, animated: true)

	}
}
