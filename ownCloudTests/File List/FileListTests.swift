//
//  CreateBookmarkTests.swift
//  ownCloudTests
//
//  Created by Javier Gonzalez on 23/10/2018.
//  Copyright © 2018 ownCloud GmbH. All rights reserved.
//

import XCTest
import EarlGrey
import ownCloudSDK
import ownCloudMocking

@testable import ownCloud

class FileListTests: XCTestCase {

	override func setUp() {
		super.setUp()
		OCBookmarkManager.deleteAllBookmarks(waitForServerlistRefresh: true)
		OCMockManager.shared.removeAllMockingBlocks()
	}

	override func tearDown() {
		super.tearDown()
		OCMockManager.shared.removeAllMockingBlocks()
	}

	public typealias OCMRequestCoreForBookmarkCompletionHandler = @convention(block)
		(_ core: OCCore, _ error: NSError?) -> Void

	public typealias OCMRequestCoreForBookmarkSetupHandler = @convention(block)
		(_ core: OCCore, _ error: NSError?) -> Void

	public typealias OCMRequestCoreForBookmark = @convention(block)
		(_ bookmark: OCBookmark, _ setup: OCMRequestCoreForBookmarkSetupHandler, _ completionHandler: OCMRequestCoreForBookmarkCompletionHandler) -> Void

	public typealias OCMRequestChangeSetWithFlags = @convention(block)
		(_ flags: OCQueryChangeSetRequestFlag, _ completionHandler: OCQueryChangeSetRequestCompletionHandler) -> Void

	/*
	* PASSED if: Disconnect button appears in the view
	*/
	func testShowFileList() {
		if let bookmark: OCBookmark = UtilsTests.getBookmark() {
			//Mocks
			self.mockOCoreForBookmark(mockBookmark: bookmark)
			self.showFileList(bookmark: bookmark)

			//Asserts
			EarlGrey.select(elementWithMatcher: grey_allOf([grey_accessibilityLabel("Back"), grey_accessibilityTrait(UIAccessibilityTraits.staticText)])).assert(grey_sufficientlyVisible())

			//Reset status
			EarlGrey.select(elementWithMatcher: grey_allOf([grey_accessibilityLabel("Back"), grey_accessibilityTrait(UIAccessibilityTraits.staticText)])).perform(grey_tap())

		} else {
			assertionFailure("File list not loaded because Bookmark is nil")
		}
	}

	/*
	* PASSED if: The expected files/folders appear in the list
	*/
	func testShowFileListWithItems() {
		let expectedCells: Int = 3

		if let bookmark: OCBookmark = UtilsTests.getBookmark() {
			//Mocks
			self.mockOCoreForBookmark(mockBookmark: bookmark)
			self.mockQueryPropfindResults(resourceName: "PropfindResponse", basePath: "/remote.php/dav/files/admin", state: .contentsFromCache)
			self.showFileList(bookmark: bookmark)
			
			//Asserts
			EarlGrey.select(elementWithMatcher: grey_allOf([grey_accessibilityLabel("Back"), grey_accessibilityTrait(UIAccessibilityTraits.staticText)])).assert(grey_sufficientlyVisible())

			var error:NSError?
			var index: UInt = 0
			while true {
				EarlGrey.select(elementWithMatcher: grey_kindOfClass(ClientItemCell.self)).atIndex(index).assert(with: grey_notNil(), error: &error)
				if error != nil {
					break
				} else {
					index += 1
				}
			}
			GREYAssertEqual(index as AnyObject, expectedCells as AnyObject, reason: "Founded \(index) cells when expected \(expectedCells)")
			
			//Asserts
			EarlGrey.select(elementWithMatcher: grey_allOf([grey_accessibilityLabel("Back"), grey_accessibilityTrait(UIAccessibilityTraits.staticText)])).assert(grey_sufficientlyVisible())

			//Reset status
			EarlGrey.select(elementWithMatcher: grey_allOf([grey_accessibilityLabel("Back"), grey_accessibilityTrait(UIAccessibilityTraits.staticText)])).perform(grey_tap())
		} else {
			assertionFailure("File list not loaded because Bookmark is nil")
		}
	}

	func showFileList(bookmark: OCBookmark) {
		if let appDelegate: AppDelegate = UIApplication.shared.delegate as? AppDelegate {
			let clientRootViewController = ClientRootViewController(bookmark: bookmark)

			appDelegate.serverListTableViewController?.navigationController?.navigationBar.prefersLargeTitles = false
			appDelegate.serverListTableViewController?.navigationController?.navigationItem.largeTitleDisplayMode = .never
			appDelegate.serverListTableViewController?.navigationController?.pushViewController(viewController: clientRootViewController, animated: true, completion: {
				appDelegate.serverListTableViewController?.navigationController?.setNavigationBarHidden(true, animated: false)
			})
		}
	}

	// MARK: - Mocks
	func mockOCoreForBookmark(mockBookmark: OCBookmark) {
		let completionHandlerBlock : OCMRequestCoreForBookmark = { (bookmark, setupHandler, mockedBlock) in
			let core = OCCore(bookmark: mockBookmark)
			setupHandler(core, nil)
			mockedBlock(core, nil)
		}

		OCMockManager.shared.addMocking(blocks: [OCMockLocation.ocCoreManagerRequestCoreForBookmark: completionHandlerBlock])
	}

	func mockQueryPropfindResults(resourceName: String, basePath: String, state: OCQueryState) {
		let completionHandlerBlock : OCMRequestChangeSetWithFlags = { (flags, mockedBlock) in

			var items: [OCItem]?

			let bundle = Bundle.main
			if let path: String = bundle.path(forResource: resourceName, ofType: "xml") {

				if let data = NSData(contentsOf: URL(fileURLWithPath: path)) {
					if let parser = OCXMLParser(data: data as Data) {
						parser.options = ["basePath": basePath]
						parser.addObjectCreationClasses([OCItem.self])
						if parser.parse() {
							items = parser.parsedObjects as? [OCItem]
						}
					}
				}
			}

			items?.removeFirst()

			let querySet: OCQueryChangeSet = OCQueryChangeSet(queryResult: items, relativeTo: nil)
			let query: OCQuery = OCQuery()
			query.state = state

			mockedBlock(query, querySet)
		}

		OCMockManager.shared.addMocking(blocks: [OCMockLocation.ocQueryRequestChangeSetWithFlags: completionHandlerBlock])
	}
}
