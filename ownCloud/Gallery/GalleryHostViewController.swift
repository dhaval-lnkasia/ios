//
//  GalleryHostViewController.swift
//  ownCloud
//
//  Created by Pablo Carrascal on 14/02/2019.
//  Copyright © 2019 ownCloud GmbH. All rights reserved.
//

import UIKit
import ownCloudSDK

class GalleryHostViewController: UIPageViewController {

	typealias Filter = ([OCItem]) -> [OCItem]

	// MARK: - Constants
	let hasChangesAvailableKeyPath: String = "hasChangesAvailable"
	let imageFilterRegexp: String = "\\A((image/*))" // Filters all the mime types that are images (incluiding gif and svg)

	// MARK: - Instance Variables
	weak private var core: OCCore?
	private var selectedItem: OCItem
	private var items: [OCItem]?
	private var query: OCQuery
	private weak var viewControllerToTansition: DisplayViewController?
	private var selectedFilter: Filter?
	private var queryObservation : NSKeyValueObservation?

	// MARK: - Filters
	lazy var filterImageFiles: Filter = { items in
		let filteredItems = items.filter({$0.type != .collection && $0.mimeType?.matches(regExp: self.imageFilterRegexp) ?? false})
		return filteredItems
	}

	lazy var filterOneItem: Filter = { items in
		let filteredItems = items.filter({$0.type != .collection && $0.fileID == self.selectedItem.fileID})
		return filteredItems
	}

	// MARK: - Init & deinit
	init(core: OCCore, selectedItem: OCItem, query: OCQuery) {
		self.core = core
		self.selectedItem = selectedItem
		self.query = query

		super.init(transitionStyle: .scroll, navigationOrientation: .horizontal, options: nil)

		if selectedItem.mimeType?.matches(regExp: imageFilterRegexp) ?? false {
			selectedFilter = filterImageFiles
		} else {
			selectedFilter = filterOneItem
		}

		queryObservation = query.observe(\OCQuery.hasChangesAvailable, options: [.initial, .new]) { [weak self] (query, _) in
			query.requestChangeSet(withFlags: .onlyResults) { ( _, changeSet) in
				guard let changeSet = changeSet  else { return }
				self?.items = self?.selectedFilter?(changeSet.queryResult)
			}
		}

		Theme.shared.register(client: self)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		queryObservation?.invalidate()
		Theme.shared.unregister(client: self)
	}

	// MARK: - ViewController lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		dataSource = self
		delegate = self

		// Display first item
		guard let mimeType = self.selectedItem.mimeType else { return }

		let viewController = self.selectDisplayViewControllerBasedOn(mimeType: mimeType)
		let configuration = self.configurationFor(self.selectedItem, viewController: viewController)

		viewController.configure(configuration)
		self.addChild(viewController)
		viewController.didMove(toParent: self)

		self.setViewControllers([viewController], direction: .forward, animated: false, completion: nil)

		viewController.present(item: self.selectedItem)
		viewController.updateNavigationBarItems()
	}

	override var childForHomeIndicatorAutoHidden : UIViewController? {
		if let childViewController = self.children.first {
			return childViewController
		}
		return nil
	}

	// MARK: - Extension selection
	private func selectDisplayViewControllerBasedOn(mimeType: String) -> (DisplayViewController) {

		let locationIdentifier = OCExtensionLocationIdentifier(rawValue: mimeType)
		let location: OCExtensionLocation = OCExtensionLocation(ofType: .viewer, identifier: locationIdentifier)
		let context = OCExtensionContext(location: location, requirements: nil, preferences: nil)

		var extensions: [OCExtensionMatch]?

		do {
			try extensions = OCExtensionManager.shared.provideExtensions(for: context)
		} catch {
			return DisplayViewController()
		}

		guard let matchedExtensions = extensions else {
			return DisplayViewController()
		}

		guard matchedExtensions.count > 0 else {
			return DisplayViewController()
		}

		let preferedExtension: OCExtension = matchedExtensions[0].extension

		let extensionObject = preferedExtension.provideObject(for: context)

		guard let controllerType = extensionObject as? (DisplayViewController & DisplayExtension) else {
			return DisplayViewController()
		}

		return controllerType
	}

	// MARK: - Helper methods
	private func viewControllerAtIndex(index: Int) -> UIViewController? {
		guard let items = items else { return nil }

		guard index >= 0, index < items.count else { return nil }

		let item = items[index]

		let newViewController = selectDisplayViewControllerBasedOn(mimeType: item.mimeType!)
		let configuration = configurationFor(item, viewController: newViewController)

		newViewController.configure(configuration)
		newViewController.present(item: item)
		return newViewController
	}

	private func configurationFor(_ item: OCItem, viewController: UIViewController) -> DisplayViewConfiguration {
		let shouldDownload = viewController is (DisplayViewController & DisplayExtension) ? true : false
		var configuration: DisplayViewConfiguration
		if !shouldDownload {
			configuration = DisplayViewConfiguration(item: item, core: core, state: .notSupportedMimeType)
		} else {
			configuration = DisplayViewConfiguration(item: item, core: core, state: .hasNetworkConnection)
		}
		return configuration
	}
}

extension GalleryHostViewController: UIPageViewControllerDataSource {
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
		if let displayViewController = viewControllers?.first as? DisplayViewController,
			let item = displayViewController.item,
			let index = items?.firstIndex(where: {$0.fileID == item.fileID}) {
			return viewControllerAtIndex(index: index + 1)
		}

		return nil

	}

	func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {

		if let displayViewController = viewControllers?.first as? DisplayViewController,
			let item = displayViewController.item,
			let index = items?.firstIndex(where: {$0.fileID == item.fileID}) {
			return viewControllerAtIndex(index: index - 1)
		}

		return nil
	}
}

extension GalleryHostViewController: UIPageViewControllerDelegate {
	func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {

		let previousViewController = previousViewControllers[0]
		previousViewController.didMove(toParent: nil)

		if completed, let viewControllerToTransition = self.viewControllerToTansition {
			if self.children.contains(viewControllerToTransition) == false {
				self.addChild(viewControllerToTransition)
			}
			viewControllerToTransition.didMove(toParent: self)
			viewControllerToTransition.updateNavigationBarItems()
		}
	}

	func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
		guard pendingViewControllers.isEmpty == false else { return }

		if let viewControllerToTransition = pendingViewControllers[0] as? DisplayViewController {
			self.viewControllerToTansition = viewControllerToTransition
		}
	}
}

extension GalleryHostViewController: Themeable {
	func applyThemeCollection(theme: Theme, collection: ThemeCollection, event: ThemeEvent) {
		self.view.backgroundColor = .black
	}
}
