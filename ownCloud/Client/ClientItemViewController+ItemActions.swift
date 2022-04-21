//
//  ClientItemViewController+ItemActions.swift
//  ownCloud
//
//  Created by Felix Schwarz on 21.04.22.
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
import ownCloudSDK
import ownCloudAppShared

extension ClientItemViewController : MoreItemHandling {
	public func moreOptions(for item: OCItem, at locationIdentifier: OCExtensionLocationIdentifier, core: OCCore, query: OCQuery?, sender: AnyObject?) -> Bool {
		guard let sender = sender else {
			return false
		}
		let actionsLocation = OCExtensionLocation(ofType: .action, identifier: locationIdentifier)
		let actionContext = ActionContext(viewController: self, core: core, query: query, items: [item], location: actionsLocation, sender: sender)

		if let moreViewController = Action.cardViewController(for: item, with: actionContext, progressHandler: makeActionProgressHandler(), completionHandler: nil) {
			self.present(asCard: moreViewController, animated: true)
		}

		return true
	}
}

extension ClientItemViewController : OpenItemHandling {
	@discardableResult public func open(item: OCItem, animated: Bool, pushViewController: Bool) -> UIViewController? {
		if let core = self.core {
			if  let bookmarkContainer = self.tabBarController as? BookmarkContainer {
				let activity = OpenItemUserActivity(detailItem: item, detailBookmark: bookmarkContainer.bookmark)
				view.window?.windowScene?.userActivity = activity.openItemUserActivity
			}

			switch item.type {
				case .collection:
					if let location = item.location {
						let queryViewController = ClientItemViewController(core: core, drive: drive, query: OCQuery(for: location), rootViewController: rootViewController)
						if pushViewController {
							self.navigationController?.pushViewController(queryViewController, animated: animated)
						}
						return queryViewController
					}

				case .file:
					guard let query = self.query else {
						return nil
					}

					let itemViewController = DisplayHostViewController(core: core, selectedItem: item, query: query)
					itemViewController.hidesBottomBarWhenPushed = true
					//!! itemViewController.progressSummarizer = self.progressSummarizer
					self.navigationController?.pushViewController(itemViewController, animated: animated)
			}
		}

		return nil
	}
}
