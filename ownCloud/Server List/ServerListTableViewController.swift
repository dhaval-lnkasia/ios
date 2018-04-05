//
//  ServerListTableViewController.swift
//  ownCloud
//
//  Created by Felix Schwarz on 08.03.18.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2018, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

import UIKit
import ownCloudSDK

class ServerListTableViewController: UITableViewController {

	@IBOutlet var welcomeOverlayView: UIView!

	override init(style: UITableViewStyle) {
		super.init(style: style)

		NotificationCenter.default.addObserver(self, selector: #selector(serverListChanged), name: Notification.Name.BookmarkManagerListChanged, object: nil)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		NotificationCenter.default.removeObserver(self, name: Notification.Name.BookmarkManagerListChanged, object: nil)
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		self.tableView.register(ServerListBookmarkCell.self, forCellReuseIdentifier: "bookmark-cell")
		self.tableView.rowHeight = UITableViewAutomaticDimension
		self.tableView.estimatedRowHeight = 80

		self.navigationItem.rightBarButtonItem =
            UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.add, target: self, action: #selector(addBookmark))

		welcomeOverlayView.translatesAutoresizingMaskIntoConstraints = false

		// Uncomment the following line to preserve selection between presentations
		// self.clearsSelectionOnViewWillAppear = false

		// Uncomment the following line to display an Edit button in the navigation bar for this view controller.

		self.navigationItem.title = "ownCloud"
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		self.navigationController?.setToolbarHidden(false, animated: animated)

		welcomeOverlayView.layoutSubviews()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		updateNoServerMessageVisibility()

		self.toolbarItems = [
			UIBarButtonItem(title: "Help", style: UIBarButtonItemStyle.plain, target: self, action: #selector(help)),
			UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.flexibleSpace, target: nil, action: nil),
			UIBarButtonItem(title: "Settings", style: UIBarButtonItemStyle.plain, target: self, action: #selector(settings))
		]
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		self.navigationController?.setToolbarHidden(true, animated: animated)
	}

	func updateNoServerMessageVisibility() {
		if BookmarkManager.sharedBookmarkManager.bookmarks.count == 0 {
			let safeAreaLayoutGuide : UILayoutGuide = self.tableView.safeAreaLayoutGuide
			var constraint : NSLayoutConstraint

			if welcomeOverlayView.superview != self.view {

				welcomeOverlayView.alpha = 0

				self.view.addSubview(welcomeOverlayView)

				UIView.animate(withDuration: 0.2, animations: {
					self.welcomeOverlayView.alpha = 1
				})

				welcomeOverlayView.centerXAnchor.constraint(equalTo: safeAreaLayoutGuide.centerXAnchor).isActive = true
				welcomeOverlayView.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor).isActive = true

				constraint = welcomeOverlayView.leftAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.leftAnchor, constant: 30)
				constraint.priority = UILayoutPriority(rawValue: 900)
				constraint.isActive = true

				constraint = welcomeOverlayView.rightAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.rightAnchor, constant: 30)
				constraint.priority = UILayoutPriority(rawValue: 900)
				constraint.isActive = true

				tableView.separatorStyle = UITableViewCellSeparatorStyle.none
				tableView.reloadData()
			}

			if self.navigationItem.leftBarButtonItem != nil {
				self.navigationItem.leftBarButtonItem = nil
			}

		} else {

			if welcomeOverlayView.superview == self.view {
				welcomeOverlayView.removeFromSuperview()

				tableView.separatorStyle = UITableViewCellSeparatorStyle.singleLine
				tableView.reloadData()
			}

			if self.navigationItem.leftBarButtonItem == nil {
				self.navigationItem.leftBarButtonItem = self.editButtonItem
			}
		}
	}

	// MARK: - Actions
	@IBAction func addBookmark() {

        let viewController : BookmarkViewController = BookmarkViewController(style: UITableViewStyle.grouped)
        self.navigationController?.pushViewController(viewController, animated: true)
		updateNoServerMessageVisibility()
	}

	@IBAction func help() {
	}

	@IBAction func settings() {
		let viewController : GlobalSettingsViewController = GlobalSettingsViewController(style: UITableViewStyle.grouped)

		self.navigationController?.pushViewController(viewController, animated: true)
	}

	// MARK: - Track external changes
	var ignoreServerListChanges : Bool = false

	@objc func serverListChanged() {
		if !ignoreServerListChanges {
			self.tableView.reloadData()
		}
	}

	// MARK: - Table view data source

	override func numberOfSections(in tableView: UITableView) -> Int {
		// #warning Incomplete implementation, return the number of sections
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		// #warning Incomplete implementation, return the number of rows
		return BookmarkManager.sharedBookmarkManager.bookmarks.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

		guard let bookmarkCell = self.tableView.dequeueReusableCell(withIdentifier: "bookmark-cell", for: indexPath) as? ServerListBookmarkCell else {

		    let cell = ServerListBookmarkCell()
		    return cell
		}

		if let bookmark : OCBookmark = BookmarkManager.sharedBookmarkManager.bookmark(at: indexPath.row) {
			bookmarkCell.titleLabel.text = bookmark.url.host
			bookmarkCell.detailLabel.text = bookmark.url.absoluteString
			bookmarkCell.imageView?.image = UIImage(named: "owncloud-primary-small")
		}

		return bookmarkCell
	}

	override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		return [
				UITableViewRowAction(style: UITableViewRowActionStyle.destructive, title: "Delete", handler: { (_, indexPath) in
					// TODO: Add confirmation prompt

					if let bookmark = BookmarkManager.sharedBookmarkManager.bookmark(at: indexPath.row) {
						self.ignoreServerListChanges = true

						BookmarkManager.sharedBookmarkManager.removeBookmark(bookmark)

						tableView.performBatchUpdates({
							tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.fade)
						}, completion: { (_) in
							self.ignoreServerListChanges = false
						})

						self.updateNoServerMessageVisibility()
					}
				})
			]
	}

	override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
		BookmarkManager.sharedBookmarkManager.moveBookmark(from: fromIndexPath.row, to: to.row)
	}
}
