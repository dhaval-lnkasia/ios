//
//  UploadBaseAction.swift
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

class UploadBaseAction: Action {

	// MARK: - Action Matching
	override class func applicablePosition(forContext: ActionContext) -> ActionPosition {
		// Only available for a single item ..
		if forContext.items.count > 1 {
			return .none
		}

		// .. that's also a directory
		if forContext.items.first?.type != .collection {
			return .none
		}

		return .middle
	}
}
