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
import PocketSVG

class ServerListTableViewController: UITableViewController, Themeable {

	@IBOutlet var welcomeOverlayView: UIView!
	@IBOutlet var welcomeTitleLabel : UILabel!
	@IBOutlet var welcomeMessageLabel : UILabel!
	@IBOutlet var welcomeAddServerButton : ThemeButton!
	@IBOutlet var welcomeLogoImageView : UIImageView!
	@IBOutlet var welcomeLogoTVGView : VectorImageView!
	// @IBOutlet var welcomeLogoSVGView : SVGImageView!

	var lockedBookmarks : [OCBookmark] = []

	override init(style: UITableView.Style) {
		super.init(style: style)

		NotificationCenter.default.addObserver(self, selector: #selector(serverListChanged), name: .OCBookmarkManagerListChanged, object: nil)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		NotificationCenter.default.removeObserver(self, name: .OCBookmarkManagerListChanged, object: nil)
	}

	// TODO: Rebuild welcomeOverlayView in code
	/*
	override func loadView() {
		super.loadView()

		welcomeOverlayView = UIView()
		welcomeOverlayView.translatesAutoresizingMaskIntoConstraints = false

		welcomeTitleLabel = UILabel()
		welcomeTitleLabel.font = UIFont.boldSystemFont(ofSize: 34)
		welcomeTitleLabel.translatesAutoresizingMaskIntoConstraints = false

		welcomeAddServerButton = ThemeButton()
	}
	*/

	override func viewDidLoad() {
		super.viewDidLoad()

		OCItem.registerIcons()

		self.navigationController?.navigationBar.prefersLargeTitles = true
		self.navigationController?.navigationBar.isTranslucent = false
		self.navigationController?.toolbar.isTranslucent = false
		self.tableView.register(ServerListBookmarkCell.self, forCellReuseIdentifier: "bookmark-cell")
		self.tableView.rowHeight = UITableView.automaticDimension
		self.tableView.estimatedRowHeight = 80
		self.tableView.allowsSelectionDuringEditing = true

		let addServerBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.add, target: self, action: #selector(addBookmark))
		addServerBarButtonItem.accessibilityLabel = "Add account".localized
		self.navigationItem.rightBarButtonItem = addServerBarButtonItem

		welcomeOverlayView.translatesAutoresizingMaskIntoConstraints = false

		Theme.shared.add(tvgResourceFor: "owncloud-logo")
		welcomeLogoTVGView.vectorImage = Theme.shared.tvgImage(for: "owncloud-logo")

		self.navigationItem.title = OCAppIdentity.shared.appName
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		self.navigationController?.setToolbarHidden(false, animated: animated)
		self.navigationController?.navigationBar.prefersLargeTitles = true

		Theme.shared.register(client: self)

		welcomeOverlayView.layoutSubviews()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		updateNoServerMessageVisibility()

		let helpBarButtonItem = UIBarButtonItem(title: "Feedback".localized, style: UIBarButtonItem.Style.plain, target: self, action: #selector(help))
		helpBarButtonItem.accessibilityIdentifier = "helpBarButtonItem"

		let settingsBarButtonItem = UIBarButtonItem(title: "Settings".localized, style: UIBarButtonItem.Style.plain, target: self, action: #selector(settings))
		settingsBarButtonItem.accessibilityIdentifier = "settingsBarButtonItem"

		self.toolbarItems = [
			helpBarButtonItem,
			UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil),
			settingsBarButtonItem
		]

		considerBetaWarning()
	}

	func considerBetaWarning() {
		let lastBetaWarningCommit = OCAppIdentity.shared.userDefaults?.string(forKey: "LastBetaWarningCommit")

		Log.log("Show beta warning: \(String(describing: VendorServices.classSetting(forOCClassSettingsKey: .showBetaWarning) as? Bool))")

		if VendorServices.classSetting(forOCClassSettingsKey: .showBetaWarning) as? Bool == true,
		   let lastGitCommit = LastGitCommit(),
		   (lastBetaWarningCommit == nil) || (lastBetaWarningCommit != lastGitCommit) {
		   	// Beta warning has never been shown before - or has last been shown for a different release
			let betaAlert = UIAlertController(with: "Beta Warning", message: "\nThis is a BETA release that may - and likely will - still contain bugs.\n\nYOU SHOULD NOT USE THIS BETA VERSION WITH PRODUCTION SYSTEMS, PRODUCTION DATA OR DATA OF VALUE. YOU'RE USING THIS BETA AT YOUR OWN RISK.\n\nPlease let us know about any issues that come up via the \"Send Feedback\" option in the settings.", okLabel: "Agree") {
				OCAppIdentity.shared.userDefaults?.set(lastGitCommit, forKey: "LastBetaWarningCommit")
				OCAppIdentity.shared.userDefaults?.set(NSDate(), forKey: "LastBetaWarningAcceptDate")
			}

			self.present(betaAlert, animated: true, completion: nil)
		}
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		self.navigationController?.setToolbarHidden(true, animated: animated)

		Theme.shared.unregister(client: self)
	}

	func applyThemeCollection(theme: Theme, collection: ThemeCollection, event: ThemeEvent) {
		welcomeAddServerButton.themeColorCollection = collection.neutralColors

		self.tableView.applyThemeCollection(collection)

		self.welcomeTitleLabel.applyThemeCollection(collection, itemStyle: .title)
		self.welcomeMessageLabel.applyThemeCollection(collection, itemStyle: .message)
	}

	func updateNoServerMessageVisibility() {
		if OCBookmarkManager.shared.bookmarks.count == 0 {
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

				self.tableView.tableHeaderView = nil
				self.navigationController?.navigationBar.shadowImage = nil

				welcomeAddServerButton.setTitle("Add account".localized, for: .normal)
				welcomeTitleLabel.text = "Welcome".localized
				let welcomeMessage = "Thanks for choosing %@! \n Start by adding your account.".localized
				welcomeMessageLabel.text = welcomeMessage.replacingOccurrences(of: "%@", with: OCAppIdentity.shared.appName ?? "ownCloud")

				tableView.separatorStyle = UITableViewCell.SeparatorStyle.none
				tableView.reloadData()
			}

			if self.navigationItem.leftBarButtonItem != nil {
				self.navigationItem.leftBarButtonItem = nil
			}

		} else {

			if welcomeOverlayView.superview == self.view {
				welcomeOverlayView.removeFromSuperview()

				tableView.separatorStyle = UITableViewCell.SeparatorStyle.singleLine
				tableView.reloadData()
			}

			if self.navigationItem.leftBarButtonItem == nil {
				self.navigationItem.leftBarButtonItem = self.editButtonItem
			}

			// Add Header View
			self.tableView.tableHeaderView = ServerListTableHeaderView(frame: CGRect(x: 0.0, y: 0.0, width: self.view.frame.size.width, height: 50.0))
			self.navigationController?.navigationBar.shadowImage = UIImage()
			self.tableView.tableHeaderView?.applyThemeCollection(Theme.shared.activeCollection)

			// UITableView background view is nil for default. Set a UIView with clear color to can insert a subview above
			let backgroundView = UIView.init(frame: self.tableView.frame)
			backgroundView.backgroundColor = UIColor.clear
			self.tableView.backgroundView = backgroundView

			// This view is needed to stop flickering when scrolling (white line between UINavigationBar and UITableView header
			let coloredView = ThemeableColoredView.init(frame: CGRect(x: 0, y: -self.view.frame.size.height, width: self.view.frame.size.width, height: self.view.frame.size.height + 1))
			coloredView.translatesAutoresizingMaskIntoConstraints = false

			self.tableView.insertSubview(coloredView, aboveSubview: self.tableView.backgroundView!)

			NSLayoutConstraint.activate([
				coloredView.topAnchor.constraint(equalTo: self.tableView.topAnchor, constant: -self.view.frame.size.height),
				coloredView.leftAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leftAnchor),
				coloredView.rightAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.rightAnchor),
				coloredView.heightAnchor.constraint(equalToConstant: self.view.frame.size.height + 1)
			])
		}
	}

	// MARK: - Actions
	@IBAction func addBookmark() {
		showBookmarkUI()
	}

	func showBookmarkUI(edit bookmark: OCBookmark? = nil) {
		let viewController : BookmarkViewController = BookmarkViewController(bookmark)
		let navigationController : ThemeNavigationController = ThemeNavigationController(rootViewController: viewController)

		// Exit editing mode (unfortunately, self.isEditing = false will not do the trick as it leaves the left bar button unchanged as "Done")
		if self.tableView.isEditing,
		   let target = self.navigationItem.leftBarButtonItem?.target,
		   let action = self.navigationItem.leftBarButtonItem?.action {
			_ = target.perform(action, with: self)
		}

		self.present(navigationController, animated: true, completion: nil)
	}

	var themeCounter : Int = 0

	@IBAction func help() {
		VendorServices.shared.sendFeedback(from: self)
	}

	@IBAction func settings() {
        	let viewController : SettingsViewController = SettingsViewController(style: .grouped)

		self.navigationController?.pushViewController(viewController, animated: true)
	}

	// MARK: - Track external changes
	var ignoreServerListChanges : Bool = false

	@objc func serverListChanged() {
		OnMainThread {
			if !self.ignoreServerListChanges {
				self.tableView.reloadData()
				self.updateNoServerMessageVisibility()
			}
		}
	}

	// MARK: - Table view delegate
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if let bookmark = OCBookmarkManager.shared.bookmark(at: UInt(indexPath.row)) {
			if lockedBookmarks.contains(bookmark) {
				let alertController = UIAlertController(title: NSString(format: "'%@' is currently locked".localized as NSString, bookmark.shortName as NSString) as String,
									message: NSString(format: "An operation is currently performed that prevents connecting to '%@'. Please try again later.".localized as NSString, bookmark.shortName as NSString) as String,
									preferredStyle: .alert)

				alertController.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: { (_) in
					// There was an error erasing the vault => re-add bookmark to give user another chance to delete its contents
					OCBookmarkManager.shared.addBookmark(bookmark)
					self.updateNoServerMessageVisibility()
				}))

				self.present(alertController, animated: true, completion: nil)

				return
			}

			if tableView.isEditing {
				self.showBookmarkUI(edit: bookmark)
			} else {
				let clientRootViewController = ClientRootViewController(bookmark: bookmark)

				self.navigationController?.navigationBar.prefersLargeTitles = false
				self.navigationController?.navigationItem.largeTitleDisplayMode = .never
				self.navigationController?.pushViewController(viewController: clientRootViewController, animated: true, completion: {
                    self.navigationController?.setNavigationBarHidden(true, animated: false)
                })
			}
		}
	}

	// MARK: - Table view data source
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return OCBookmarkManager.shared.bookmarks.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard let bookmarkCell = self.tableView.dequeueReusableCell(withIdentifier: "bookmark-cell", for: indexPath) as? ServerListBookmarkCell else {
		    return ServerListBookmarkCell()
		}

		if let bookmark : OCBookmark = OCBookmarkManager.shared.bookmark(at: UInt(indexPath.row)) {
			bookmarkCell.titleLabel.text = bookmark.shortName
			bookmarkCell.detailLabel.text = (bookmark.originURL != nil) ? bookmark.originURL!.absoluteString : bookmark.url?.absoluteString
			bookmarkCell.accessibilityIdentifier = "server-bookmark-cell"
		}

		return bookmarkCell
	}

	override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		return [
				UITableViewRowAction(style: .destructive, title: "Delete".localized, handler: { (_, indexPath) in
					if let bookmark = OCBookmarkManager.shared.bookmark(at: UInt(indexPath.row)) {
						var presentationStyle: UIAlertController.Style = .actionSheet
						if UIDevice.current.isIpad() {
							presentationStyle = .alert
						}

						let alertController = UIAlertController(title: NSString(format: "Really delete '%@'?".localized as NSString, bookmark.shortName) as String,
											     message: "This will also delete all locally stored file copies.".localized,
											     preferredStyle: presentationStyle)

						alertController.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))

						alertController.addAction(UIAlertAction(title: "Delete".localized, style: .destructive, handler: { (_) in

							self.lockedBookmarks.append(bookmark)

							OCCoreManager.shared.scheduleOfflineOperation({ (bookmark, completionHandler) in
								let vault : OCVault = OCVault(bookmark: bookmark)

								vault.erase(completionHandler: { (_, error) in
									OnMainThread {
										if error != nil {
											// Inform user if vault couldn't be erased
											let alertController = UIAlertController(title: NSString(format: "Deletion of '%@' failed".localized as NSString, bookmark.shortName as NSString) as String,
																message: error?.localizedDescription,
																preferredStyle: .alert)

											alertController.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: nil))

											self.present(alertController, animated: true, completion: nil)
										} else {
											// Success! We can now remove the bookmark
											self.ignoreServerListChanges = true

											OCBookmarkManager.shared.removeBookmark(bookmark)

											tableView.performBatchUpdates({
												tableView.deleteRows(at: [indexPath], with: UITableView.RowAnimation.fade)
											}, completion: { (_) in
												self.ignoreServerListChanges = false
											})

											self.updateNoServerMessageVisibility()
										}

										if let removeIndex = self.lockedBookmarks.index(of: bookmark) {
											self.lockedBookmarks.remove(at: removeIndex)
										}

										completionHandler()
									}
								})
							}, for: bookmark)
						}))

						self.present(alertController, animated: true, completion: nil)
					}
				}),

				UITableViewRowAction(style: .normal, title: "Edit".localized, handler: { [weak self] (_, indexPath) in
					if let bookmark = OCBookmarkManager.shared.bookmark(at: UInt(indexPath.row)) {
						self?.showBookmarkUI(edit: bookmark)
					}
				})
			]
	}

	override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
		OCBookmarkManager.shared.moveBookmark(from: UInt(fromIndexPath.row), to: UInt(to.row))
	}
}
