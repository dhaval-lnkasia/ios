//
//  StaticTableViewController.swift
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

public enum StaticTableViewEvent {
	case initial
	case appBecameActive
	case tableViewWillAppear
	case tableViewWillDisappear
	case tableViewDidDisappear
}

open class StaticTableViewController: UITableViewController, Themeable {
	public var sections : [StaticTableViewSection] = Array()

	public var needsLiveUpdates : Bool {
		return (self.view.window != nil) || hasBeenPresentedAtLeastOnce
	}

	private var hasBeenPresentedAtLeastOnce : Bool = false

	// MARK: - Section administration
	public func addSection(_ section: StaticTableViewSection, animated animateThis: Bool = false) {
		self.insertSection(section, at: sections.count, animated: animateThis)
	}

	public func insertSection(_ section: StaticTableViewSection, at index: Int, animated: Bool = false) {
		section.viewController = self

		if animated {
			tableView.performBatchUpdates({
				sections.insert(section, at: index)
				tableView.insertSections(IndexSet(integer: index), with: .fade)
			})
		} else {
			sections.insert(section, at: index)

			tableView.reloadData()
		}
	}

	public func removeSection(_ section: StaticTableViewSection, animated: Bool = false) {
		if animated {
			tableView.performBatchUpdates({
				if let index = sections.index(of: section) {
					sections.remove(at: index)
					tableView.deleteSections(IndexSet(integer: index), with: .fade)
				}
			}, completion: { (_) in
				section.viewController = nil
			})
		} else {
			if let sectionIndex = sections.index(of: section) {
				sections.remove(at: sectionIndex)

				section.viewController = nil

				tableView.reloadData()
			} else {
				section.viewController = nil
			}
		}
	}

	public func addSections(_ addSections: [StaticTableViewSection], animated animateThis: Bool = false) {
		for section in addSections {
			section.viewController = self
		}

		if animateThis {
			tableView.performBatchUpdates({
				let index = sections.count
				sections.append(contentsOf: addSections)
				tableView.insertSections(IndexSet(integersIn: index..<(index+addSections.count)), with: UITableView.RowAnimation.fade)
			})
		} else {
			sections.append(contentsOf: addSections)
			tableView.reloadData()
		}
	}

	public func removeSections(_ removeSections: [StaticTableViewSection], animated animateThis: Bool = false) {
		if animateThis {
			tableView.performBatchUpdates({
				var removalIndexes : IndexSet = IndexSet()

				for section in removeSections {
					if let index : Int = sections.index(of: section) {
						removalIndexes.insert(index)
					}
				}

				for section in removeSections {
					if let index : Int = sections.index(of: section) {
						sections.remove(at: index)
					}
				}

				tableView.deleteSections(removalIndexes, with: .fade)
			}, completion: { (_) in
				for section in removeSections {
					section.viewController = nil
				}
			})
		} else {
			for section in removeSections {
				sections.remove(at: sections.index(of: section)!)
				section.viewController = nil
			}

			tableView.reloadData()
		}
	}

	// MARK: - Search
	public func sectionForIdentifier(_ sectionID: String) -> StaticTableViewSection? {
		for section in sections {
			if section.identifier == sectionID {
				return section
			}
		}

		return nil
	}

	public func rowInSection(_ inSection: StaticTableViewSection?, rowIdentifier: String) -> StaticTableViewRow? {
		if inSection == nil {
			for section in sections {
				if let row = section.row(withIdentifier: rowIdentifier) {
					return row
				}
			}
		} else {
			return inSection?.row(withIdentifier: rowIdentifier)
		}

		return nil
	}

	// MARK: - View Controller
	override open func viewDidLoad() {
		super.viewDidLoad()

		extendedLayoutIncludesOpaqueBars = true
		Theme.shared.register(client: self)
	}

	public var willDismissAction : ((_ viewController: StaticTableViewController) -> Void)?
	public var didDismissAction : ((_ viewController: StaticTableViewController) -> Void)?

	@objc public func dismissAnimated() {
		self.willDismissAction?(self)
		self.dismiss(animated: true, completion: {
			self.didDismissAction?(self)
		})
	}

	override open func viewWillAppear(_ animated: Bool) {
		hasBeenPresentedAtLeastOnce = true

		super.viewWillAppear(animated)
	}

	deinit {
		Theme.shared.unregister(client: self)
	}

	// MARK: - Tools
	public func staticRowForIndexPath(_ indexPath: IndexPath) -> StaticTableViewRow {
		return (sections[indexPath.section].rows[indexPath.row])
	}

	// MARK: - Table view data source
	override public func numberOfSections(in tableView: UITableView) -> Int {
		return sections.count
	}

	override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return sections[section].rows.count
	}

	override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		return sections[indexPath.section].rows[indexPath.row].cell!
	}

	override public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

		let staticRow : StaticTableViewRow = staticRowForIndexPath(indexPath)

		if let action = staticRow.action {
			action(staticRow, self)
		}

		tableView.deselectRow(at: indexPath, animated: true)
	}

	override public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return sections[section].headerTitle
	}

	override public func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
		return sections[section].footerTitle
	}

	open override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		if sections[section].headerTitle != nil || sections[section].headerView != nil {
			return UITableView.automaticDimension
		}

		return 0.0
	}

	open override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
		if sections[section].footerTitle != nil || sections[section].footerView != nil {
			return UITableView.automaticDimension
		}

		return 0.0
	}

	override public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		let cell = staticRowForIndexPath(indexPath)
		if cell.type == .datePicker {
			return 216.0
		}

		return UITableView.automaticDimension
	}

	open override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		return sections[section].headerView
	}

	open override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
		return sections[section].footerView
	}

	// MARK: - Theme support
	open func applyThemeCollection(theme: Theme, collection: ThemeCollection, event: ThemeEvent) {
		self.tableView.applyThemeCollection(collection)
	}
}
