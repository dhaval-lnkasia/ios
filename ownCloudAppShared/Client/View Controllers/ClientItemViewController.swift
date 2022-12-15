//
//  ClientItemViewController.swift
//  ownCloudAppShared
//
//  Created by Felix Schwarz on 14.04.22.
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
import ownCloudApp
import Intents

open class ClientItemViewController: CollectionViewController, SortBarDelegate, DropTargetsProvider, SearchViewControllerDelegate, RevealItemAction, SearchViewControllerHost {
	public enum ContentState : String, CaseIterable {
		case loading

		case empty
		case removed
		case hasContent

		case searchNonItemContent
	}

	public var query: OCQuery?
	private var _itemsDatasource: OCDataSource? // stores the data source passed to init (if any)

	public var itemsLeadInDataSource: OCDataSourceArray = OCDataSourceArray()
	public var itemsListDataSource: OCDataSource? // typically query.queryResultsDataSource or .itemsDatasource
	public var itemsTrailingDataSource: OCDataSourceArray = OCDataSourceArray()
	public var itemSectionDataSource: OCDataSourceComposition?
	public var itemSection: CollectionViewSection?

	public var driveSection: CollectionViewSection?

	public var driveSectionDataSource: OCDataSourceComposition?
	public var singleDriveDatasource: OCDataSourceComposition?
	private var singleDriveDatasourceSubscription: OCDataSourceSubscription?
	public var driveAdditionalItemsDataSource: OCDataSourceArray = OCDataSourceArray()

	public var emptyItemListDataSource: OCDataSourceArray = OCDataSourceArray()
	public var emptyItemListDecisionSubscription: OCDataSourceSubscription?
	public var emptyItemListItem: ComposedMessageView?
	public var emptySectionDataSource: OCDataSourceComposition?
	public var emptySection: CollectionViewSection?

	public var loadingListItem: ComposedMessageView?
	public var folderRemovedListItem: ComposedMessageView?
	public var footerItem: UIView?
	public var footerFolderStatisticsLabel: UILabel?

	public var location: OCLocation?

	private var stateObservation: NSKeyValueObservation?
	private var queryStateObservation: NSKeyValueObservation?
	private var queryRootItemObservation: NSKeyValueObservation?

	var navigationTitleLabel: UILabel = UILabel()

	private var viewControllerUUID: UUID

	public init(context inContext: ClientContext?, query inQuery: OCQuery?, itemsDatasource inDataSource: OCDataSource? = nil, location: OCLocation? = nil, highlightItemReference: OCDataItemReference? = nil, showRevealButtonForItems: Bool = false) {
		inQuery?.queryResultsDataSourceIncludesStatistics = true
		query = inQuery
		_itemsDatasource = inDataSource

		self.location = location

		var sections : [ CollectionViewSection ] = []

		let vcUUID = UUID()
		viewControllerUUID = vcUUID

		let itemControllerContext = ClientContext(with: inContext, modifier: { context in
			// Add permission handler limiting interactions for specific items and scenarios
			context.add(permissionHandler: { (context, record, interaction, viewController) in
				guard  let viewController = viewController as? ClientItemViewController, viewController.viewControllerUUID == vcUUID else {
					// Only apply this permission handler to this view controller, otherwise -> just pass through
					return true
				}

				switch interaction {
					case .selection:
						if record?.type == .drive {
							// Do not react to taps on the drive header cells (=> or show image in the future)
							return false
						}

						return true

					case .multiselection:
						if record?.type == .item {
							// Only allow selection of items
							return true
						}

						return false

					case .drag:
						// Do not allow drags when in multi-selection mode
						return (context?.originatingViewController as? ClientItemViewController)?.isMultiSelecting == false

					case .contextMenu:
						// Do not allow context menus when in multi-selection mode
						return (context?.originatingViewController as? ClientItemViewController)?.isMultiSelecting == false

					default:
						return true
				}
			})

			// Use inDataSource as queryDatasource if no query was provided
			if inQuery == nil, let inDataSource {
				context.queryDatasource = inDataSource
			}
		})
		itemControllerContext.postInitializationModifier = { (owner, context) in
			if context.openItemHandler == nil {
				context.openItemHandler = owner as? OpenItemAction
			}
			if context.moreItemHandler == nil {
				context.moreItemHandler = owner as? MoreItemAction
			}
			if context.revealItemHandler == nil {
				context.revealItemHandler = owner as? RevealItemAction
			}
			if context.dropTargetsProvider == nil {
				context.dropTargetsProvider = owner as? DropTargetsProvider
			}

			context.query = (owner as? ClientItemViewController)?.query
			if let sortMethod = (owner as? ClientItemViewController)?.sortMethod,
			   let sortDirection = (owner as? ClientItemViewController)?.sortDirection {
				// Set default sort descriptor
				context.sortDescriptor = SortDescriptor(method: sortMethod, direction: sortDirection)
			}

			context.originatingViewController = owner as? UIViewController
		}

		if let contentsDataSource = query?.queryResultsDataSource ?? _itemsDatasource, let core = itemControllerContext.core {
			itemsListDataSource = contentsDataSource

			if query?.queryLocation?.isRoot == true, core.useDrives {
				// Create data source from one drive
				singleDriveDatasource = OCDataSourceComposition(sources: [core.drivesDataSource])
				singleDriveDatasource?.filter = OCDataSourceComposition.itemFilter(withItemRetrieval: false, fromRecordFilter: { itemRecord in
					if let drive = itemRecord?.item as? OCDrive {
						if drive.identifier == itemControllerContext.drive?.identifier,
						   drive.specialType == .space { // limit to spaces, do not show header for f.ex. the personal space or the Shares Jail space
							return true
						}
					}

					return false
				})

				// Create combined data source from drive + additional items
				driveSectionDataSource = OCDataSourceComposition(sources: [ singleDriveDatasource!, driveAdditionalItemsDataSource ])

				// Create drive section from combined data source
				driveSection = CollectionViewSection(identifier: "drive", dataSource: driveSectionDataSource, cellStyle: .init(with: .header), cellLayout: .list(appearance: .plain))
			}

			itemSectionDataSource = OCDataSourceComposition(sources: [itemsLeadInDataSource, contentsDataSource, itemsTrailingDataSource])
			let itemSectionCellStyle = CollectionViewCellStyle(from: .init(with: .tableCell), changing: { cellStyle in
				if showRevealButtonForItems {
					cellStyle.showRevealButton = true
				}
			})

			itemSection = CollectionViewSection(identifier: "items", dataSource: itemSectionDataSource, cellStyle: itemSectionCellStyle, cellLayout: .list(appearance: .plain, contentInsets: NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)), clientContext: itemControllerContext)

			if let driveSection = driveSection {
				sections.append(driveSection)
			}

			if let queryItemDataSourceSection = itemSection {
				sections.append(queryItemDataSourceSection)
			}
		}

		emptySectionDataSource = OCDataSourceComposition(sources: [ emptyItemListDataSource ])

		emptySection = CollectionViewSection(identifier: "empty", dataSource: emptySectionDataSource, cellStyle: .init(with: .fillSpace), cellLayout: .fullWidth(itemHeightDimension: .estimated(54), groupHeightDimension: .estimated(54), edgeSpacing: NSCollectionLayoutEdgeSpacing(leading: .fixed(0), top: .fixed(10), trailing: .fixed(0), bottom: .fixed(10)), contentInsets: NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)), clientContext: itemControllerContext)
		sections.append(emptySection!)

		super.init(context: itemControllerContext, sections: sections, useStackViewRoot: true, highlightItemReference: highlightItemReference)

		// Track query state and recompute content state when it changes
		stateObservation = itemsListDataSource?.observe(\OCDataSource.state, options: [], changeHandler: { [weak self] query, change in
			self?.recomputeContentState()
		})

		queryStateObservation = query?.observe(\OCQuery.state, options: [], changeHandler: { [weak self] query, change in
			self?.recomputeContentState()
		})

		queryRootItemObservation = query?.observe(\OCQuery.rootItem, options: [], changeHandler: { [weak self] query, change in
			OnMainThread(inline: true) {
				self?.clientContext?.rootItem = query.rootItem
				self?.updateNavigationTitleFromContext()
				self?.refreshEmptyActions()
			}
			self?.recomputeContentState()
		})

		// Subscribe to singleDriveDatasource for changes, to update driveSectionDataSource
		singleDriveDatasourceSubscription = singleDriveDatasource?.subscribe(updateHandler: { [weak self] (subscription) in
			self?.updateAdditionalDriveItems(from: subscription)
		}, on: .main, trackDifferences: true, performIntialUpdate: true)

		if let queryDatasource = query?.queryResultsDataSource {
			let emptyFolderMessage = "This folder is empty.".localized // "This folder is empty. Fill it with content:".localized

			emptyItemListItem = ComposedMessageView(elements: [
				.image(OCSymbol.icon(forSymbolName: "folder.fill")!, size: CGSize(width: 64, height: 48), alignment: .centered),
				.text("No contents".localized, style: .system(textStyle: .title3, weight: .semibold), alignment: .centered),
				.spacing(5),
				.text(emptyFolderMessage, style: .systemSecondary(textStyle: .body), alignment: .centered)
			])

			emptyItemListItem?.elementInsets = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 2, trailing: 0)
			emptyItemListItem?.backgroundView = nil

			let indeterminateProgress: Progress = .indeterminate()
			indeterminateProgress.isCancellable = false

			loadingListItem = ComposedMessageView(elements: [
				.spacing(25),
				.progressCircle(with: indeterminateProgress),
				.spacing(25),
				.text("Loading…".localized, style: .system(textStyle: .title3, weight: .semibold), alignment: .centered)
			])

			folderRemovedListItem = ComposedMessageView(elements: [
				.image(OCSymbol.icon(forSymbolName: "nosign")!, size: CGSize(width: 64, height: 48), alignment: .centered),
				.text("Folder removed".localized, style: .system(textStyle: .title3, weight: .semibold), alignment: .centered),
				.spacing(5),
				.text("This folder no longer exists on the server.".localized, style: .systemSecondary(textStyle: .body), alignment: .centered)
			])

			footerItem = UIView()
			footerItem?.translatesAutoresizingMaskIntoConstraints = false

			footerFolderStatisticsLabel = UILabel()
			footerFolderStatisticsLabel?.translatesAutoresizingMaskIntoConstraints = false
			footerFolderStatisticsLabel?.font = UIFont.systemFont(ofSize: UIFont.smallSystemFontSize)
			footerFolderStatisticsLabel?.textAlignment = .center
			footerFolderStatisticsLabel?.setContentHuggingPriority(.required, for: .vertical)
			footerFolderStatisticsLabel?.setContentCompressionResistancePriority(.required, for: .vertical)
			footerFolderStatisticsLabel?.numberOfLines = 0
			footerFolderStatisticsLabel?.text = "-"

			footerItem?.embed(toFillWith: footerFolderStatisticsLabel!, insets: NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
			footerItem?.separatorLayoutGuideCustomizer = SeparatorLayoutGuideCustomizer(with: { viewCell, view in
				return [ viewCell.separatorLayoutGuide.leadingAnchor.constraint(equalTo: viewCell.contentView.trailingAnchor) ]
			})
			footerItem?.layoutIfNeeded()

			emptyItemListDecisionSubscription = queryDatasource.subscribe(updateHandler: { [weak self] (subscription) in
				self?.updateEmptyItemList(from: subscription)
			}, on: .main, trackDifferences: false, performIntialUpdate: true)
		}

		// Initialize sort method
		handleSortMethodChange()

		// Initialize navigation title
		navigationTitleLabel.font = UIFont.systemFont(ofSize: UIFont.buttonFontSize, weight: .semibold)
		navigationTitleLabel.lineBreakMode = .byTruncatingMiddle
		navigationItem.titleView = navigationTitleLabel

		updateNavigationTitleFromContext()
	}

	required public init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	deinit {
		stateObservation?.invalidate()
		queryRootItemObservation?.invalidate()
		queryStateObservation?.invalidate()
		singleDriveDatasourceSubscription?.terminate()
	}

	public override func viewDidLoad() {
		super.viewDidLoad()

		// Add navigation bar button items
		updateNavigationBarButtonItems()

		// Setup sort bar
		sortBar = SortBar(sortMethod: sortMethod)
		sortBar?.translatesAutoresizingMaskIntoConstraints = false
		sortBar?.delegate = self
		sortBar?.sortMethod = sortMethod
		sortBar?.searchScope = searchScope
		sortBar?.showSelectButton = true

		itemsLeadInDataSource.setVersionedItems([ sortBar! ])

		// Setup multiselect
		collectionView.allowsSelectionDuringEditing = true
		collectionView.allowsMultipleSelectionDuringEditing = true

//		navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .bookmarks, primaryAction: UIAction(handler: { [weak self] _ in
//			self?.splitViewController?.show(.primary)
//		}))
	}

	public override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		if let query = query {
			clientContext?.core?.start(query)
		}
	}

	open override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		if let query = query {
			clientContext?.core?.stop(query)
		}
	}

	public func updateAdditionalDriveItems(from subscription: OCDataSourceSubscription) {
		let snapshot = subscription.snapshotResettingChangeTracking(true)

		if let core = clientContext?.core,
		   let firstItemRef = snapshot.items.first,
	  	   let itemRecord = try? subscription.source?.record(forItemRef: firstItemRef),
		   let drive = itemRecord.item as? OCDrive,
		   let driveRepresentation = OCDataRenderer.default.renderItem(drive, asType: .presentable, error: nil) as? OCDataItemPresentable,
		   let descriptionResourceRequest = try? driveRepresentation.provideResourceRequest(.coverDescription) {
			driveQuota = drive.quota

			descriptionResourceRequest.lifetime = .singleRun
			descriptionResourceRequest.changeHandler = { [weak self] (request, error, isOngoing, previousResource, newResource) in
				// Log.debug("REQ_Readme request: \(String(describing: request)) | error: \(String(describing: error)) | isOngoing: \(isOngoing) | newResource: \(String(describing: newResource))")
				if let textResource = newResource as? OCResourceText {
					self?.driveAdditionalItemsDataSource.setItems([textResource], updated: [textResource])
				}
			}

			core.vault.resourceManager?.start(descriptionResourceRequest)
		}
	}

	var _actionProgressHandler : ActionProgressHandler?

	// MARK: - Empty item list handling
	func emptyActions() -> [OCAction]? {
		guard let context = clientContext, let core = context.core, let item = context.query?.rootItem, clientContext?.hasPermission(for: .addContent) == true else {
			return nil
		}
		let locationIdentifier: OCExtensionLocationIdentifier = .emptyFolder
		let originatingViewController : UIViewController = context.originatingViewController ?? self
		let actionsLocation = OCExtensionLocation(ofType: .action, identifier: locationIdentifier)
		let actionContext = ActionContext(viewController: originatingViewController, clientContext: clientContext, core: core, query: context.query, items: [item], location: actionsLocation, sender: self)

		let emptyFolderActions = Action.sortedApplicableActions(for: actionContext)
		let actions = emptyFolderActions.map({ action in action.provideOCAction() })

		return (actions.count > 0) ? actions : nil
	}

	func updateEmptyItemList(from subscription: OCDataSourceSubscription) {
		recomputeContentState()
	}

	func recomputeContentState() {
		OnMainThread {
			if self.searchActive == true {
				// Search is active, adapt state to either results (.hasContent) or noResults/suggestions (.searchNonItemContent)
				if let searchResultsContent = self.searchResultsContent {
					if searchResultsContent.type != .results {
						self.contentState = .searchNonItemContent
					} else {
						self.contentState = .hasContent
					}
				} else {
					self.contentState = .searchNonItemContent
				}
			} else {
				// Regular usage, use itemsQueryDataSource to determine state
				switch self.itemsListDataSource?.state {
					case .loading:
						self.contentState = .loading

					case .idle:
						let snapshot = self.emptyItemListDecisionSubscription?.snapshotResettingChangeTracking(true)
						let numberOfItems = snapshot?.numberOfItems

						if self.query?.state == .targetRemoved {
							self.contentState = .removed
						} else if let numberOfItems = numberOfItems, numberOfItems > 0 {
							self.contentState = .hasContent
							self.folderStatistics = snapshot?.specialItems?[.folderStatistics] as? OCStatistic
						} else if (numberOfItems == nil) || (self.query?.rootItem == nil) {
							self.contentState = .loading
						} else {
							self.contentState = .empty
						}

					default: break
				}
			}
		}
	}

	private var hadRootItem: Bool = false
	private var hadSearchActive: Bool?
	public var contentState : ContentState = .loading {
		didSet {
			let hasRootItem = (query?.rootItem != nil)
			let itemSectionHidden = itemSection?.hidden
			var itemSectionHiddenNew = false
			let emptySectionHidden = emptySection?.hidden
			var emptySectionHiddenNew = false
			let changeFromOrToRemoved = ((contentState == .removed) || (oldValue == .removed)) && (oldValue != contentState)

			if (contentState == oldValue) && (hadRootItem == hasRootItem) && (hadSearchActive == searchActive) {
				return
			}

			hadRootItem = hasRootItem
			hadSearchActive = searchActive

			switch contentState {
				case .empty:
					refreshEmptyActions()
					itemsLeadInDataSource.setVersionedItems([ ])
					itemsTrailingDataSource.setVersionedItems([ ])

				case .loading:
					var loadingItems : [OCDataItem] = [ ]

					if let loadingListItem = loadingListItem {
						loadingItems.append(loadingListItem)
					}
					emptyItemListDataSource.setItems(loadingItems, updated: nil)
					itemsLeadInDataSource.setVersionedItems([ ])
					itemsTrailingDataSource.setVersionedItems([ ])

				case .removed:
					var folderRemovedItems : [OCDataItem] = [ ]

					if let folderRemovedListItem = folderRemovedListItem {
						folderRemovedItems.append(folderRemovedListItem)
					}
					emptyItemListDataSource.setItems(folderRemovedItems, updated: nil)
					itemsLeadInDataSource.setVersionedItems([ ])
					itemsTrailingDataSource.setVersionedItems([ ])

				case .hasContent:
					emptyItemListDataSource.setItems(nil, updated: nil)
					if let sortBar = sortBar {
						itemsLeadInDataSource.setVersionedItems([ sortBar ])
					}

					if searchActive == true {
						itemsTrailingDataSource.setVersionedItems([ ])
					} else {
						if let footerItem = footerItem {
							itemsTrailingDataSource.setVersionedItems([ footerItem ])
						}
					}

					emptySectionHiddenNew = true

				case .searchNonItemContent:
					emptyItemListDataSource.setItems(nil, updated: nil)
					itemsLeadInDataSource.setVersionedItems([ ])
					itemsTrailingDataSource.setVersionedItems([ ])
					itemSectionHiddenNew = true
			}

			if changeFromOrToRemoved {
				updateNavigationBarButtonItems()
			}

			if (itemSectionHidden != itemSectionHiddenNew) || (emptySectionHidden != emptySectionHiddenNew) {
				updateSections(with: { sections in
					self.itemSection?.hidden = itemSectionHiddenNew
					self.emptySection?.hidden = emptySectionHiddenNew
				}, animated: false)
			}
		}
	}

	// MARK: - Navigation Bar
	open func updateNavigationBarButtonItems() {
		var rightInset : CGFloat = 2
		var leftInset : CGFloat = 0
		if self.view.effectiveUserInterfaceLayoutDirection == .rightToLeft {
			rightInset = 0
			leftInset = 2
		}

		var viewActionButtons : [UIBarButtonItem] = []

		if contentState != .removed {
			if query?.queryLocation != nil {
				// More menu for folder
				if clientContext?.moreItemHandler != nil, clientContext?.hasPermission(for: .moreOptions) == true {
					let folderActionBarButton = UIBarButtonItem(image: UIImage(named: "more-dots")?.withInset(UIEdgeInsets(top: 0, left: leftInset, bottom: 0, right: rightInset)), style: .plain, target: self, action: #selector(moreBarButtonPressed))
					folderActionBarButton.accessibilityIdentifier = "client.folder-action"
					folderActionBarButton.accessibilityLabel = "Actions".localized

					viewActionButtons.append(folderActionBarButton)
				}

				// Plus button for folder
				if clientContext?.hasPermission(for: .addContent) == true {
					let plusBarButton = UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil)
					plusBarButton.menu = UIMenu(title: "", children: [
						UIDeferredMenuElement.uncached({ [weak self] completion in
							if let self = self, let rootItem = self.query?.rootItem, let clientContext = self.clientContext {
								let contextMenuProvider = rootItem as DataItemContextMenuInteraction

								if let contextMenuElements = contextMenuProvider.composeContextMenuItems(in: self, location: .folderAction, with: clientContext) {
									    completion(contextMenuElements)
								}
							}
						})
					])
					plusBarButton.accessibilityIdentifier = "client.file-add"
					plusBarButton.accessibilityLabel = "Add item".localized

					viewActionButtons.append(plusBarButton)
				}

				// Add search button
				if clientContext?.hasPermission(for: .search) == true {
					let searchButton = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(startSearch))
					searchButton.accessibilityIdentifier = "client.search"
					searchButton.accessibilityLabel = "Search".localized
					viewActionButtons.append(searchButton)
				}
			}
		}

		self.navigationItem.rightBarButtonItems = viewActionButtons
	}

	@objc open func moreBarButtonPressed(_ sender: UIBarButtonItem) {
		guard let rootItem = query?.rootItem else {
			return
		}

		if let moreItemHandler = clientContext?.moreItemHandler, let clientContext = clientContext {
			moreItemHandler.moreOptions(for: rootItem, at: .moreFolder, context: clientContext, sender: sender)
		}
	}

	// MARK: - Navigation title
	var navigationTitle: String? {
		get {
			return navigationTitleLabel.text
		}

		set {
			navigationTitleLabel.text = newValue
			navigationItem.title = newValue
		}
	}

	func updateNavigationTitleFromContext() {
		if let navigationTitle = query?.queryLocation?.isRoot == true ? self.clientContext?.drive?.name : ((self.clientContext?.rootItem as? OCItem)?.name ?? self.query?.queryLocation?.lastPathComponent) {
			self.navigationTitle = navigationTitle
		} else {
			self.navigationTitle = navigationItem.title
		}
	}

	// MARK: - Sorting
	open var sortBar: SortBar?
	open var sortMethod: SortMethod {
		set {
			UserDefaults.standard.setValue(newValue.rawValue, forKey: "sort-method")
			handleSortMethodChange()
		}

		get {
			let sort = SortMethod(rawValue: UserDefaults.standard.integer(forKey: "sort-method")) ?? SortMethod.alphabetically
			return sort
		}
	}
	open var searchScope: SortBarSearchScope = .local // only for SortBarDelegate protocol conformance
	open var sortDirection: SortDirection {
		set {
			UserDefaults.standard.setValue(newValue.rawValue, forKey: "sort-direction")
		}

		get {
			let direction = SortDirection(rawValue: UserDefaults.standard.integer(forKey: "sort-direction")) ?? SortDirection.ascendant
			return direction
		}
	}
	open func handleSortMethodChange() {
		let sortDescriptor = SortDescriptor(method: sortMethod, direction: sortDirection)

		clientContext?.sortDescriptor = sortDescriptor
		query?.sortComparator = sortDescriptor.comparator
	}

	public func sortBar(_ sortBar: SortBar, didUpdateSortMethod: SortMethod) {
 		sortMethod = didUpdateSortMethod

 		let comparator = sortMethod.comparator(direction: sortDirection)

 		query?.sortComparator = comparator
// 		customSearchQuery?.sortComparator = comparator
//
//		if (customSearchQuery?.queryResults?.count ?? 0) >= maxResultCount {
//	 		updateCustomSearchQuery()
//		}
	}

	public func sortBar(_ sortBar: SortBar, didUpdateSearchScope: SortBarSearchScope) {
		 // only for SortBarDelegate protocol conformance
	}

	public func sortBar(_ sortBar: SortBar, presentViewController: UIViewController, animated: Bool, completionHandler: (() -> Void)?) {
		self.present(presentViewController, animated: animated, completion: completionHandler)
	}

	// MARK: - Multiselect
	public func toggleSelectMode() {
		if let clientContext = clientContext, clientContext.hasPermission(for: .multiselection) {
			isMultiSelecting = !isMultiSelecting
		}
	}

	var multiSelectionActionContext: ActionContext?
	var multiSelectionActionsDatasource: OCDataSourceArray?

	var multiSelectionLeftNavigationItem: UIBarButtonItem?
	var multiSelectionLeftNavigationItems: [UIBarButtonItem]?
	var multiSelectionToggleSelectionBarButtonItem: UIBarButtonItem? {
		willSet {
			if multiSelectionToggleSelectionBarButtonItem == nil {
				multiSelectionLeftNavigationItem = navigationItem.leftBarButtonItem
				multiSelectionLeftNavigationItems = navigationItem.leftBarButtonItems
			}
		}

		didSet {
			if multiSelectionToggleSelectionBarButtonItem == nil {
				navigationItem.leftBarButtonItem = multiSelectionLeftNavigationItem
				navigationItem.leftBarButtonItems = multiSelectionLeftNavigationItems
			} else {
				navigationItem.leftBarButtonItem = multiSelectionToggleSelectionBarButtonItem
			}
		}
	}

	public var isMultiSelecting : Bool = false {
		didSet {
			if oldValue != isMultiSelecting {
				collectionView.isEditing = isMultiSelecting

				if isMultiSelecting {
					// Setup new action context
					if let core = clientContext?.core {
						let actionsLocation = OCExtensionLocation(ofType: .action, identifier: .multiSelection)
						multiSelectionActionContext = ActionContext(viewController: self, clientContext: clientContext, core: core, query: query, items: [OCItem](), location: actionsLocation)
					}

					// Setup select all / deselect all in navigation item
					multiSelectionToggleSelectionBarButtonItem = UIBarButtonItem(title: "Select All".localized, primaryAction: UIAction(handler: { [weak self] action in
						self?.selectDeselectAll()
					}))

					// Setup multi selection action datasource
					multiSelectionActionsDatasource = OCDataSourceArray()
					refreshMultiselectActions()
					showActionsBar(with: multiSelectionActionsDatasource!)
				} else {
					// Restore navigation item
					closeActionsBar()
					multiSelectionToggleSelectionBarButtonItem = nil
					multiSelectionActionsDatasource = nil
					multiSelectionActionContext = nil
				}
			}
		}
	}

	private var noActionsTextItem : OCDataItemPresentable?

	func refreshMultiselectActions() {
		if let multiSelectionActionContext = multiSelectionActionContext {
			var actionItems : [OCDataItem & OCDataItemVersioning] = []

			if multiSelectionActionContext.items.count == 0 {
				if noActionsTextItem == nil {
					noActionsTextItem = OCDataItemPresentable(reference: "_emptyActionList" as NSString, originalDataItemType: nil, version: nil)
					noActionsTextItem?.title = "Select one or more items.".localized
					noActionsTextItem?.childrenDataSourceProvider = nil
				}

				if let noActionsTextItem = noActionsTextItem {
					actionItems = [ noActionsTextItem ]
					OnMainThread {
						self.actionsBarViewControllerSection?.animateDifferences = true
					}
				}

				multiSelectionToggleSelectionBarButtonItem?.title = "Select All".localized
			} else {
				let actions = Action.sortedApplicableActions(for: multiSelectionActionContext)
				let actionCompletionHandler : ActionCompletionHandler = { [weak self] action, error in
					OnMainThread {
						self?.isMultiSelecting = false
					}
				}

				for action in actions {
					action.completionHandler = actionCompletionHandler
					actionItems.append(action.provideOCAction(singleVersion: true))
				}

				multiSelectionToggleSelectionBarButtonItem?.title = "Deselect All".localized
			}

			multiSelectionActionsDatasource?.setVersionedItems(actionItems)
		}
	}

	public override func handleMultiSelection(of record: OCDataItemRecord, at indexPath: IndexPath, isSelected: Bool, clientContext: ClientContext) -> Bool {
		if !super.handleMultiSelection(of: record, at: indexPath, isSelected: isSelected, clientContext: clientContext),
		   let multiSelectionActionContext = multiSelectionActionContext {
			retrieveItem(at: indexPath, synchronous: true, action: { [weak self] record, indexPath, _ in
				if record.type == .item, let item = record.item as? OCItem {
					if isSelected {
						multiSelectionActionContext.add(item: item)
					} else {
						multiSelectionActionContext.remove(item: item)
					}

					self?.refreshMultiselectActions()
				}
			})
		}

		return true
	}

	func itemRefs(for items: [OCItem]) -> [ItemRef] {
		return items.map { item in
			return item.dataItemReference
		}
	}

	private var selectAllSubscription: OCDataSourceSubscription?

	open func selectDeselectAll() {
		if let selectedItems = multiSelectionActionContext?.items, selectedItems.count > 0 {
			// Deselect all
			let selectedIndexPaths = retrieveIndexPaths(for: itemRefs(for: selectedItems))

			for indexPath in selectedIndexPaths {
				collectionView.deselectItem(at: indexPath, animated: false)
				self.collectionView(collectionView, didDeselectItemAt: indexPath)
			}
		} else {
			// Select all
			selectAllSubscription = itemsListDataSource?.subscribe(updateHandler: { (subscription) in
				let snapshot = subscription.snapshotResettingChangeTracking(true)
				let selectIndexPaths = self.retrieveIndexPaths(for: snapshot.items)

				for indexPath in selectIndexPaths {
					self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .left)
					self.collectionView(self.collectionView, didSelectItemAt: indexPath)
				}

				subscription.terminate()
				self.selectAllSubscription = nil
			}, on: .main, trackDifferences: false, performIntialUpdate: true)
		}
	}

	// MARK: - Drag & Drop
	public override func targetedDataItem(for indexPath: IndexPath?, interaction: ClientItemInteraction) -> OCDataItem? {
		var dataItem: OCDataItem? = super.targetedDataItem(for: indexPath, interaction: interaction)

		if interaction == .acceptDrop {
			if let indexPath = indexPath {
				if let section = section(at: indexPath.section) {
					if (section == emptySection) || (section == driveSection) || ((dataItem as? OCItem)?.type == .file), clientContext?.hasPermission(for: interaction) == true {
						// Return root item of view controller if a drop operation targets
						// - the empty section
						// - the drive (header) section
						// - a file
						// and drops are permitted
						dataItem = clientContext?.rootItem
					}
				}
			}
		}

		return dataItem
	}

	// MARK: Drop Targets
	var dropTargetsActionContext: ActionContext?

	public func canProvideDropTargets(for dropSession: UIDropSession, target: UIView) -> Bool {
		for item in dropSession.items {
			if item.localObject == nil, item.itemProvider.hasItemConformingToTypeIdentifier("public.folder") {
				// folders can't be imported from other apps
				return false
			} else if let localDataItem = item.localObject as? LocalDataItem,
				  clientContext?.core?.bookmark.uuid != localDataItem.bookmarkUUID,
				  (localDataItem.dataItem as? OCItem)?.type == .collection {
				// folders from other accounts can't be dropped
				return false
			}
		}

		if dropSession.localDragSession != nil {
			if provideDropItems(from: dropSession, target: target).count == 0 {
				return false
			}
		}

		return true
	}

	public func provideDropItems(from dropSession: UIDropSession, target view: UIView) -> [OCItem] {
		var items : [OCItem] = []
		var allItemsFromSameAccount = true

		if let bookmarkUUID = clientContext?.core?.bookmark.uuid {
			for dragItem in dropSession.items {
				if let localDataItem = dragItem.localObject as? LocalDataItem {
					if localDataItem.bookmarkUUID != bookmarkUUID {
						allItemsFromSameAccount = false
						break
					} else {
						if let item = localDataItem.dataItem as? OCItem {
							items.append(item)
						}
					}
				} else {
					allItemsFromSameAccount = false
					break
				}
			}
		}

		if !allItemsFromSameAccount {
			items.removeAll()
		}

		return items
	}

	public func provideDropTargets(for dropSession: UIDropSession, target view: UIView) -> [OCDataItem & OCDataItemVersioning]? {
		let items = provideDropItems(from: dropSession, target: view)

		if items.count > 0, let core = clientContext?.core {
			dropTargetsActionContext = ActionContext(viewController: self, clientContext: clientContext, core: core, items: items, location: OCExtensionLocation(ofType: .action, identifier: .dropAction))

			if let dropTargetsActionContext = dropTargetsActionContext {
				let actions = Action.sortedApplicableActions(for: dropTargetsActionContext)

				return actions.map { action in action.provideOCAction(singleVersion: true) }
			}
		}

		return nil
	}

	public func cleanupDropTargets(for dropSession: UIDropSession, target view: UIView) {
		dropTargetsActionContext = nil
	}

	// MARK: - Reveal
	public func reveal(item: OCDataItem, context: ClientContext, sender: AnyObject?) -> Bool {
		if let revealInteraction = item as? DataItemSelectionInteraction {
			if revealInteraction.revealItem?(from: self, with: context, animated: true, pushViewController: true, completion: nil) != nil {
				return true
			}
		}
		return false
	}

	// MARK: - Search
	open var searchController: UISearchController?
	open var searchViewController: SearchViewController?

	@objc open func startSearch() {
		if searchViewController == nil {
			if let clientContext = clientContext, let cellStyle = itemSection?.cellStyle {
				var scopes : [SearchScope] = [
					// - In this folder
					.modifyingQuery(with: clientContext, localizedName: "Folder".localized),

					// - Folder and subfolders (tree / container)
					.containerSearch(with: clientContext, cellStyle: cellStyle, localizedName: "Tree".localized)
				]

				// - Drive
				if clientContext.core?.useDrives == true {
					let driveName = "Space".localized
					scopes.append(.driveSearch(with: clientContext, cellStyle: cellStyle, localizedName: driveName))
				}

				// - Account
				scopes.append(.accountSearch(with: clientContext, cellStyle: cellStyle, localizedName: "Account".localized))

				// No results
				let noResultContent = SearchViewController.Content(type: .noResults, source: OCDataSourceArray(), style: emptySection!.cellStyle)
				let noResultsView = ComposedMessageView.infoBox(image: OCSymbol.icon(forSymbolName: "magnifyingglass"), title: "No matches".localized, subtitle: "The search term you entered did not match any item in the selected scope.".localized)

				(noResultContent.source as? OCDataSourceArray)?.setVersionedItems([
					noResultsView
				])

				// Suggestion view
				let suggestionsSource = OCDataSourceArray()
				let suggestionsContent = SearchViewController.Content(type: .suggestion, source: suggestionsSource, style: emptySection!.cellStyle)

				if let vault = clientContext.core?.vault {
					vault.addSavedSearchesObserver(suggestionsSource, withInitial: true) { suggestionsSource, savedSearches, isInitial in
						guard let suggestionsSource = suggestionsSource as? OCDataSourceArray else {
							return
						}

						var suggestionItems : [OCDataItem & OCDataItemVersioning] = []

						// Offer saved search templates
						if let savedTemplates = vault.savedSearches?.filter({ savedSearch in
							return savedSearch.isTemplate
						}), savedTemplates.count > 0 {
							let savedSearchTemplatesHeaderView = ComposedMessageView(elements: [
								.spacing(10),
								.text("Saved search templates".localized, style: .system(textStyle: .headline), alignment: .leading, insets: .zero)
							])
							savedSearchTemplatesHeaderView.elementInsets = .zero

							suggestionItems.append(savedSearchTemplatesHeaderView)
							suggestionItems.append(contentsOf: savedTemplates)
						}

						// Offer saved searches
						if let savedSearches = vault.savedSearches?.filter({ savedSearch in
							return !savedSearch.isTemplate
						}), savedSearches.count > 0 {
							let savedSearchTemplatesHeaderView = ComposedMessageView(elements: [
								.spacing(10),
								.text("Saved searches".localized, style: .system(textStyle: .headline), alignment: .leading, insets: .zero)
							])
							savedSearchTemplatesHeaderView.elementInsets = .zero

							suggestionItems.append(savedSearchTemplatesHeaderView)
							suggestionItems.append(contentsOf: savedSearches)
						}

						// Provide "Enter a search term" placeholder if there is no other content available
						if suggestionItems.count == 0 {
							suggestionItems.append( ComposedMessageView.infoBox(image: nil, subtitle: "Enter a search term".localized) )
						}

						suggestionsSource.setVersionedItems(suggestionItems)
					}
				}

				// Create and install SearchViewController
				searchViewController = SearchViewController(with: clientContext, scopes: scopes, suggestionContent: suggestionsContent, noResultContent: noResultContent, delegate: self)

				if let searchViewController = searchViewController {
					self.addStacked(child: searchViewController, position: .top)
				}
			}
		}
	}

	func endSearch() {
		if let searchViewController = searchViewController {
			self.removeStacked(child: searchViewController)
		}
		searchResultsContent = nil
		searchViewController = nil

		itemSectionDataSource?.setInclude(true, for: itemsLeadInDataSource)
	}

	// MARK: - SearchViewControllerDelegate
	var searchResultsContent: SearchViewController.Content? {
		didSet {
			if let content = searchResultsContent {
				let contentSource = content.source
				let contentStyle = content.style

				switch content.type {
					case .results:
						if searchResultsDataSource != contentSource {
							searchResultsDataSource = contentSource
						}

						if let style = contentStyle ?? preSearchCellStyle, style != itemSection?.cellStyle {
							itemSection?.cellStyle = style
						}

						searchNonItemDataSource = nil

					case .noResults, .suggestion:
						searchResultsDataSource = nil
						searchNonItemDataSource = contentSource
				}
			} else {
				searchResultsDataSource = nil
				searchNonItemDataSource = nil
			}

			recomputeContentState()
		}
	}

	var searchResultsDataSource: OCDataSource? {
		willSet {
			if let oldDataSource = searchResultsDataSource, let itemsQueryDataSource = itemsListDataSource, oldDataSource != itemsQueryDataSource {
				itemSectionDataSource?.removeSources([ oldDataSource ])

				if (newValue == nil) || (newValue == itemsQueryDataSource) {
					itemSectionDataSource?.setInclude(true, for: itemsQueryDataSource)
				}
			}
		}

		didSet {
			if let newDataSource = searchResultsDataSource, let itemsQueryDataSource = itemsListDataSource, newDataSource != itemsQueryDataSource {
				itemSectionDataSource?.setInclude(false, for: itemsQueryDataSource)
				itemSectionDataSource?.insertSources([ newDataSource ], after: itemsQueryDataSource)
			}
		}
	}

	var searchNonItemDataSource: OCDataSource? {
		willSet {
			if let oldDataSource = searchNonItemDataSource, oldDataSource != newValue {
				emptySectionDataSource?.removeSources([ oldDataSource ])
			}
		}

		didSet {
			if let newDataSource = searchNonItemDataSource, newDataSource != oldValue {
				emptySectionDataSource?.addSources([ newDataSource ])
			}
		}
	}

	private var preSearchCellStyle : CollectionViewCellStyle?
	var searchActive : Bool?

	public func searchBegan(for viewController: SearchViewController) {
		preSearchCellStyle = itemSection?.cellStyle
		searchActive = true

		updateSections(with: { sections in
			self.driveSection?.hidden = true
		}, animated: true)
	}

	public func search(for viewController: SearchViewController, content: SearchViewController.Content?) {
		searchResultsContent = content
	}

	public func searchEnded(for viewController: SearchViewController) {
		searchActive = false

		updateSections(with: { sections in
			self.driveSection?.hidden = false
		}, animated: true)

		if let preSearchCellStyle = preSearchCellStyle {
			itemSection?.cellStyle = preSearchCellStyle
		}

		endSearch()

		recomputeContentState()
	}

	// MARK: - Statistics
	var folderStatistics: OCStatistic? {
		didSet {
			self.updateStatisticsFooter()
		}
	}

	var driveQuota: GAQuota? {
		didSet {
			self.updateStatisticsFooter()
		}
	}

	func updateStatisticsFooter() {
		var folderStatisticsText: String = ""
		var quotaInfoText: String = ""

		if let folderStatistics = folderStatistics {
			folderStatisticsText = "{{itemCount}} items with {{totalSize}} total ({{fileCount}} files, {{folderCount}} folders)".localized([
				"itemCount" : NumberFormatter.localizedString(from: NSNumber(value: folderStatistics.itemCount?.intValue ?? 0), number: .decimal),
				"fileCount" : NumberFormatter.localizedString(from: NSNumber(value: folderStatistics.fileCount?.intValue ?? 0), number: .decimal),
				"folderCount" : NumberFormatter.localizedString(from: NSNumber(value: folderStatistics.folderCount?.intValue ?? 0), number: .decimal),
				"totalSize" : folderStatistics.localizedSize ?? "-"
			])
		}

		if let driveQuota = driveQuota, let remainingBytes = driveQuota.remaining {
			quotaInfoText = "{{remaining}} available".localized([
				"remaining" : ByteCountFormatter.string(fromByteCount: remainingBytes.int64Value, countStyle: .file)
			])

			if folderStatisticsText.count > 0 {
				folderStatisticsText += "\n" + quotaInfoText
			} else {
				folderStatisticsText = quotaInfoText
			}
		}

		OnMainThread {
			if let footerFolderStatisticsLabel = self.footerFolderStatisticsLabel {
				footerFolderStatisticsLabel.text = folderStatisticsText
			}
		}
	}

	// MARK: - Empty actions
	func refreshEmptyActions() {
		guard contentState == .empty else { return }

		var emptyItems : [OCDataItem] = [ ]

		if let emptyItemListItem = emptyItemListItem {
			emptyItems.append(emptyItemListItem)
		}

		if let emptyActions = emptyActions() {
			emptyItems.append(contentsOf: emptyActions)
		}

		emptyItemListDataSource.setItems(emptyItems, updated: nil)
	}

	// MARK: - Themeing
	public override func applyThemeCollection(theme: Theme, collection: ThemeCollection, event: ThemeEvent) {
		super.applyThemeCollection(theme: theme, collection: collection, event: event)
		navigationTitleLabel.textColor = collection.navigationBarColors.labelColor
		footerFolderStatisticsLabel?.textColor = collection.tableRowColors.secondaryLabelColor
	}
}
