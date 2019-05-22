//
//  PublicLinkTableViewController.swift
//  ownCloud
//
//  Created by Matthias Hühne on 01.05.19.
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

class PublicLinkTableViewController: SharingTableViewController {

	// MARK: - Instance Variables
	var shares : [OCShare] = []

	override func viewDidLoad() {
		super.viewDidLoad()

		messageView = MessageView(add: self.view)

		self.navigationItem.title = "Links".localized
		self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissAnimated))
		self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addPublicLink))

		addHeaderView()
		addPrivateLinkSection()

		shareQuery = core?.sharesWithReshares(for: item, initialPopulationHandler: { [weak self] (sharesWithReshares) in
			if let self = self, sharesWithReshares.count > 0 {
				self.shares = sharesWithReshares.filter { (share) -> Bool in
					if share.type == .link {
						return true
					}
					return false
				}
				OnMainThread {
					self.addShareSections()
				}
			}
		}, changesAvailableNotificationHandler: { [weak self] (sharesWithReshares) in
			guard let self = self else { return }
			let sharesWithReshares = sharesWithReshares.filter { (share) -> Bool in
				if share.type == .link {
					return true
				}
				return false
			}
			self.shares = sharesWithReshares
			OnMainThread {
				self.removeShareSections()
				self.addShareSections()
				self.handleEmptyShares()
			}
		}, keepRunning: true)
		shareQuery?.refreshInterval = 2
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		handleEmptyShares()
	}

	// MARK: - Sharing UI

	func addSectionFor(type: OCShareType, with title: String) {
		var shareRows: [StaticTableViewRow] = []

		let user = shares.filter { (share) -> Bool in
			if share.type == type {
				return true
			}
			return false
		}

		if user.count > 0 {
			for share in user {
				if canEdit(share: share) {
					shareRows.append( StaticTableViewRow(rowWithAction: { [weak self] (_, _) in
						guard let self = self else { return }
						let editPublicLinkViewController = PublicLinkEditTableViewController(style: .grouped)
						editPublicLinkViewController.share = share
						editPublicLinkViewController.core = self.core
						editPublicLinkViewController.item = self.item
						self.navigationController?.pushViewController(editPublicLinkViewController, animated: true)
					}, title: share.name!, subtitle: share.permissionDescription(), accessoryType: .disclosureIndicator) )
				} else {
					shareRows.append( StaticTableViewRow(rowWithAction: nil, title: share.name!, subtitle: share.permissionDescription(), accessoryType: .none) )
				}
			}
		} else {
			shareRows.append( StaticTableViewRow(buttonWithAction: { [weak self] (_, _) in
				self?.addPublicLink()
			}, title: "Create Public Link".localized, style: StaticTableViewRowButtonStyle.plain))
		}

		let sectionType = "share-section-\(String(type.rawValue))"
		if let section = self.sectionForIdentifier(sectionType) {
			self.removeSection(section)
		}
		let section : StaticTableViewSection = StaticTableViewSection(headerTitle: title, footerTitle: nil, identifier: sectionType, rows: shareRows)
		self.addSection(section, animated: false)
	}

	func addShareSections() {
		OnMainThread {
			self.addSectionFor(type: .link, with: "Public Links".localized)
		}
	}

	func removeShareSections() {
		OnMainThread {
			let types : [OCShareType] = [.link]
			for type in types {
				let identifier = "share-section-\(String(type.rawValue))"
				if let section = self.sectionForIdentifier(identifier) {
					self.removeSection(section)
				}
			}
		}
	}

	func resetTable(showShares : Bool) {
		removeShareSections()
		if shares.count > 0 && showShares {
			messageView?.message(show: false)
		}
		self.addShareSections()
	}

	func handleEmptyShares() {
		if shares.count == 0 {
			OnMainThread {
				self.resetTable(showShares: false)
			}
		}
	}

	// MARK: - Private Link Section

	func addPrivateLinkSection() {
		let identifier = "private-link-section"
		if let section = self.sectionForIdentifier(identifier) {
			self.removeSection(section)
		}

		let footer = "Only collaborators can use this link. Use it as a permanent link to point to this resource".localized

		OnMainThread {
			let section = StaticTableViewSection(headerTitle: nil, footerTitle: footer, identifier: "private-link-section")
			var rows : [StaticTableViewRow] = []

			self.core?.retrievePrivateLink(for: self.item, completionHandler: { (error, url) in

				guard let url = url else { return }
				if error == nil {
					OnMainThread {
						let privateLinkRow = StaticTableViewRow(headerRowWithAction: { [weak self] (row, _) in
							guard let self = self else { return }
							self.retrievePrivateLink(for: self.item, in: row)
						}, headerTitle: String(format:"%@", url.absoluteString), title: "Copy Private Link".localized, accessoryView: nil)
						rows.append(privateLinkRow)

						section.add(rows: rows)
						self.insertSection(section, at: 0)
					}
				}
			})
		}
	}

	func retrievePrivateLink(for item: OCItem, in row: StaticTableViewRow) {
		let progressView = UIActivityIndicatorView(style: Theme.shared.activeCollection.activityIndicatorViewStyle)
		progressView.startAnimating()
		row.cell?.accessoryView = progressView

		self.core?.retrievePrivateLink(for: item, completionHandler: { (error, url) in
			OnMainThread {
				row.cell?.accessoryView = nil
			}
			if error == nil {
				guard let url = url else { return }
				UIPasteboard.general.url = url
			}
		})
	}

	// MARK: - Sharing Helper
	func canEdit(share: OCShare) -> Bool {
		if core?.connection.loggedInUser?.userName == share.owner?.userName || core?.connection.loggedInUser?.userName == share.itemOwner?.userName {
			return true
		}

		return false
	}

	// MARK: TableView Delegate

	override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		let share = self.shares[indexPath.row]
		if self.canEdit(share: share) {
			return [
				UITableViewRowAction(style: .destructive, title: "Delete".localized, handler: { (_, _) in
					var presentationStyle: UIAlertController.Style = .actionSheet
					if UIDevice.current.isIpad() {
						presentationStyle = .alert
					}

					let alertController = UIAlertController(title: "Delete Public Link".localized,
															message: nil,
															preferredStyle: presentationStyle)
					alertController.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))

					alertController.addAction(UIAlertAction(title: "Delete".localized, style: .destructive, handler: { (_) in
							self.core?.delete(share, completionHandler: { (error) in
								OnMainThread {
									if error == nil {
										self.navigationController?.popViewController(animated: true)
									} else {
										if let shareError = error {
											let alertController = UIAlertController(with: "Delete Public Link failed".localized, message: shareError.localizedDescription, okLabel: "OK".localized, action: nil)
											self.present(alertController, animated: true)
										}
									}
								}
							})
					}))

					self.present(alertController, animated: true, completion: nil)
				}),

				UITableViewRowAction(style: .normal, title: "Copy".localized, handler: { (_, _) in
					if let shareURL = share.url {
						UIPasteboard.general.url = shareURL
					}
				})
			]
		}

		return []
	}

	// MARK: Add New Link Share

	@objc func addPublicLink() {
		if let path = item.path, let name = item.name {
			var permissions = OCSharePermissionsMask.create
			if item.type == .file {
				permissions = OCSharePermissionsMask.read
			}

			var linkName = String(format:"%@ %@ (%ld)", name, "Link".localized, (shares.count + 1))
			if let defaultLinkName = core?.connection.capabilities?.publicSharingDefaultLinkName {
				linkName = defaultLinkName
			}

			let share = OCShare(publicLinkToPath: path, linkName: linkName, permissions: permissions, password: nil, expiration: nil)
			let editPublicLinkViewController = PublicLinkEditTableViewController(style: .grouped)
			editPublicLinkViewController.share = share
			editPublicLinkViewController.core = self.core
			editPublicLinkViewController.item = self.item
			editPublicLinkViewController.createLink = true
			let navigationController = ThemeNavigationController(rootViewController: editPublicLinkViewController)
			self.navigationController?.present(navigationController, animated: true, completion: nil)
		}
	}
}
