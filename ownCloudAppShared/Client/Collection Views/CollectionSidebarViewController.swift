//
//  ClientSidebarViewController.swift
//  ownCloudAppShared
//
//  Created by Felix Schwarz on 07.11.22.
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

open class CollectionSidebarViewController: CollectionViewController {
	open var originalContext: ClientContext
	open var sidebarContext: ClientContext

	public typealias ViewControllerNavigationPusher = (_ viewController: UIViewController, _ animated: Bool) -> Void

	open var navigationPusher: ViewControllerNavigationPusher?

	public init(context inContext: ClientContext, sections: [CollectionViewSection], navigationPusher: ViewControllerNavigationPusher? = nil, highlightItemReference: OCDataItemReference? = nil) {
		originalContext = inContext

		if let navigationPusher = navigationPusher {
			sidebarContext = ClientContext(with: originalContext)

			sidebarContext.postInitializationModifier = { (owner, context) in
				context.viewControllerPusher = owner as? ViewControllerPusher
			}

			self.navigationPusher = navigationPusher
		} else {
			sidebarContext = inContext
		}

		super.init(context: sidebarContext, sections: sections, highlightItemReference: highlightItemReference)
	}

	required public init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

extension CollectionSidebarViewController: ViewControllerPusher {
	public func pushViewController(context: ClientContext?, provider: (ClientContext) -> UIViewController?, push: Bool, animated: Bool) -> UIViewController? {
		var effectiveContext: ClientContext? = context

		if effectiveContext == sidebarContext {
			// Pass original context instead of sidebar context
			effectiveContext = originalContext
		} else {
			// Create new context without viewControllerPusher if CollectionSidebarViewController is set as pusher of the current context
			if effectiveContext?.viewControllerPusher === self {
				effectiveContext = ClientContext(with: context, modifier: { context in
					context.viewControllerPusher = nil
				})
			}
		}

		if let effectiveContext = effectiveContext,
		   let viewController = provider(effectiveContext) {
			if push {
				// Push view controller
				if let navigationPusher = navigationPusher {
					// Use pusher
					navigationPusher(viewController, animated)
				} else {
					// Use navigation controller
					if let navigationController = effectiveContext.navigationController {
						navigationController.pushViewController(viewController, animated: animated)
					}
				}
			}

			return viewController
		}

		return nil
	}
}
