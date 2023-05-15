//
//  ClientSharedByMeViewController.swift
//  ownCloudAppShared
//
//  Created by Felix Schwarz on 06.01.23.
//  Copyright © 2023 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2023, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

import UIKit
import ownCloudSDK

class ClientSharedByMeViewController: CollectionViewController {
	var hasByMeSection: Bool
	var sharedByMeSection: CollectionViewSection?

	var hasByLinkSection: Bool
	var sharedByLinkSection: CollectionViewSection?

	var noItemsCondition: DataSourceCondition?

	init(context inContext: ClientContext?, byMe: Bool = false, byLink: Bool = false) {
		hasByMeSection = byMe
		hasByLinkSection = byLink
		let context = ClientContext(with: inContext, modifier: { context in
			context.viewControllerPusher = nil
		})
		super.init(context: context, sections: nil, useStackViewRoot: true)
		revoke(in: inContext, when: [ .connectionClosed ])
		navigationItem.titleLabelText = (byMe && !byLink) ? "Shared by me".localized : ((!byMe && byLink) ? "Shared by link".localized : "Shared".localized)
	}

	required public init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	var noShareMessage: ComposedMessageView?
	var connectionStatusObservation: NSKeyValueObservation?

	override func viewDidLoad() {
		super.viewDidLoad()

		func buildSection(identifier: CollectionViewSection.SectionIdentifier, titled title: String, contentDataSource: OCDataSource) -> CollectionViewSection {
			let section = CollectionViewSection(identifier: identifier, dataSource: contentDataSource, cellStyle: .init(with: .tableCell), cellLayout: .list(appearance: .plain, contentInsets: NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 20, trailing: 0)), clientContext: clientContext)
			section.hideIfEmptyDataSource = contentDataSource
			section.hidden = true

			section.boundarySupplementaryItems = [
				.title(title, pinned: true)
			]

			return section
		}

		func addNoItemsCondition(imageName: String, title: String, datasource: OCDataSource) {
			noShareMessage = ComposedMessageView(elements: [
				.image(OCSymbol.icon(forSymbolName: imageName)!, size: CGSize(width: 64, height: 48), alignment: .centered),
				.title(title, alignment: .centered)
			])

			noItemsCondition = DataSourceCondition(.empty, with: datasource, initial: true, action: { [weak self] condition in
				self?.updateCoverMessage()
			})
		}

		var sectionsToAdd: [CollectionViewSection] = []

		if hasByMeSection, let byMeDataSource = clientContext?.core?.sharedByMeGroupedDataSource {
			sharedByMeSection = buildSection(identifier: "byMe", titled: "Shared by me".localized, contentDataSource: byMeDataSource)
			sectionsToAdd.append(sharedByMeSection!)

			addNoItemsCondition(imageName: "arrowshape.turn.up.right", title: "No items shared by you".localized, datasource: byMeDataSource)
		}

		if hasByLinkSection, let byLinkDataSource = clientContext?.core?.sharedByLinkDataSource {
			sharedByLinkSection = buildSection(identifier: "byLink", titled: "Shared by link".localized, contentDataSource: byLinkDataSource)
			sectionsToAdd.append(sharedByLinkSection!)

			addNoItemsCondition(imageName: "link", title: "No items shared by link".localized, datasource: byLinkDataSource)
		}

		add(sections: sectionsToAdd)

		connectionStatusObservation = clientContext?.core?.observe(\OCCore.connectionStatus, options: .initial, changeHandler: { [weak self] core, change in
			OnMainThread {
				self?.updateCoverMessage()
			}
		})
	}

	func updateCoverMessage() {
		var coverView: UIView?

		if clientContext?.core?.connectionStatus != .online {
			let offlineMessage = ComposedMessageView(elements: [
				.image(OCSymbol.icon(forSymbolName: "network")!, size: CGSize(width: 64, height: 48), alignment: .centered),
				.title("Sharing requires an active connection.".localized, alignment: .centered)
			])

			coverView = offlineMessage
		}

		if coverView == nil, noItemsCondition?.fulfilled == true {
			coverView = noShareMessage
		}

		setCoverView(coverView, layout: .top)
	}
}
