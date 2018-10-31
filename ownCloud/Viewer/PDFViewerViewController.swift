//
//  PDFViewerViewController.swift
//  ownCloud
//
//  Created by Pablo Carrascal on 29/08/2018.
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
import PDFKit

extension UILabel {
    func _setupPdfInfoLabel() {
        self.layer.masksToBounds = true
        self.layer.cornerRadius = 8.0
        self.backgroundColor = UIColor.darkGray
        self.textColor = UIColor.white
        self.font = UIFont.systemFont(ofSize: 14.0, weight: UIFont.Weight.medium)
        self.translatesAutoresizingMaskIntoConstraints = false
        self.textAlignment = .center
        self.adjustsFontSizeToFitWidth = true
    }
}

class PDFViewerViewController: DisplayViewController, DisplayExtension {

    enum ThumbnailViewPosition {
        case left, right, bottom, none
        func isVertical() -> Bool {
            return self == .bottom ? false : true
        }
    }

    static let PDFGoToPageNotification = Notification(name: Notification.Name(rawValue: "PDFGoToPageNotification"))

	fileprivate var gotoPageNotificationObserver : Any?

    fileprivate let searchAnnotationDelay = 3.0
    fileprivate let thumbnailViewWidthMultiplier: CGFloat = 0.15
    fileprivate let thumbnailViewHeightMultiplier: CGFloat = 0.1
    fileprivate let filenameContainerTopMargin: CGFloat = 10.0
    fileprivate let pdfView = PDFView()
    fileprivate let thumbnailView = PDFThumbnailView()

    fileprivate let containerView = UIStackView()
    fileprivate let pageCountLabel = UILabel()
    fileprivate let fileNameLabel = UILabel()

    fileprivate var searchButtonItem: UIBarButtonItem?
    fileprivate var gotoButtonItem: UIBarButtonItem?
    fileprivate var outlineItem: UIBarButtonItem?

    fileprivate var thumbnailViewPosition : ThumbnailViewPosition = .bottom {
        didSet {
            switch thumbnailViewPosition {
            case .left, .right:
                thumbnailView.layoutMode = .vertical
            case .bottom:
                thumbnailView.layoutMode = .horizontal
            default:
                break
            }

            pageCountLabel.isHidden = thumbnailViewPosition == .none ? true : false
            fileNameLabel.isHidden = thumbnailViewPosition == .none ? true : false

            setupConstraints()
        }
    }

    fileprivate var activeViewConstraints: [NSLayoutConstraint] = [] {
        willSet {
            NSLayoutConstraint.deactivate(activeViewConstraints)
        }
        didSet {
            NSLayoutConstraint.activate(activeViewConstraints)
        }
    }

    // MARK: - DisplayExtension

    static var customMatcher: OCExtensionCustomContextMatcher?
    static var displayExtensionIdentifier: String = "org.owncloud.pdfViewer.default"
    static var supportedMimeTypes: [String]? = ["application/pdf"]
    static var features: [String : Any]? = [FeatureKeys.canEdit : false]

    deinit {
        NotificationCenter.default.removeObserver(self)
        if gotoPageNotificationObserver != nil {
	        NotificationCenter.default.removeObserver(gotoPageNotificationObserver!)
	}
    }

    override func renderSpecificView() {
        if let document = PDFDocument(url: source) {
            setupToolbar()

            self.view.backgroundColor = UIColor.gray
            self.thumbnailViewPosition = .none

            // Configure thumbnail view
            thumbnailView.translatesAutoresizingMaskIntoConstraints = false
            thumbnailView.backgroundColor = UIColor.gray
            thumbnailView.pdfView = pdfView
            thumbnailView.isExclusiveTouch = true

            // Adding dummy tap recognizer to prevent navigation bar from hiding if user just taps it
            let tapRecognizer = UITapGestureRecognizer(target: nil, action: nil)
            thumbnailView.addGestureRecognizer(tapRecognizer)
            self.view.addSubview(thumbnailView)

            containerView.spacing = UIStackView.spacingUseSystem
            containerView.isLayoutMarginsRelativeArrangement = true
            containerView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: filenameContainerTopMargin,
                                                                             leading: 0,
                                                                             bottom: 0,
                                                                             trailing: 0)
            containerView.backgroundColor = UIColor.lightGray
            containerView.translatesAutoresizingMaskIntoConstraints = false
            containerView.axis = .vertical
            containerView.distribution = .fill

            let fileNameContainerView = UIView()
            fileNameContainerView.backgroundColor = UIColor.gray
            fileNameContainerView.translatesAutoresizingMaskIntoConstraints = false
            fileNameContainerView.addSubview(fileNameLabel)

            fileNameLabel._setupPdfInfoLabel()
            fileNameLabel.centerXAnchor.constraint(equalTo: fileNameContainerView.centerXAnchor).isActive = true
            fileNameLabel.centerYAnchor.constraint(equalTo: fileNameContainerView.centerYAnchor).isActive = true
            fileNameLabel.widthAnchor.constraint(equalTo: fileNameContainerView.widthAnchor, multiplier: 0.9).isActive = true
            fileNameLabel.heightAnchor.constraint(equalTo: fileNameContainerView.heightAnchor, multiplier: 0.9).isActive = true

            containerView.addArrangedSubview(fileNameContainerView)

            // Configure PDFView instance
            pdfView.displayDirection = .horizontal
            pdfView.translatesAutoresizingMaskIntoConstraints = false
            pdfView.usePageViewController(true, withViewOptions: nil)
            containerView.addArrangedSubview(pdfView)

            let pageCountContainerView = UIView()
            pageCountContainerView.backgroundColor = UIColor.gray
            pageCountContainerView.translatesAutoresizingMaskIntoConstraints = false
            pageCountContainerView.addSubview(pageCountLabel)

            pageCountLabel._setupPdfInfoLabel()
            pageCountLabel.centerXAnchor.constraint(equalTo: pageCountContainerView.centerXAnchor).isActive = true
            pageCountLabel.centerYAnchor.constraint(equalTo: pageCountContainerView.centerYAnchor).isActive = true
            pageCountLabel.widthAnchor.constraint(equalTo: pageCountContainerView.widthAnchor, multiplier: 0.25).isActive = true
            pageCountLabel.heightAnchor.constraint(equalTo: pageCountContainerView.heightAnchor, multiplier: 0.9).isActive = true

            containerView.addArrangedSubview(pageCountContainerView)

            self.view.addSubview(containerView)

            setupConstraints()

            pdfView.document = document
            fileNameLabel.text = document.documentURL?.lastPathComponent

            pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
            pdfView.autoScales = true
            updatePageLabel()
        }
    }

    // MARK: - View lifecycle management

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(handlePageChanged), name: .PDFViewPageChanged, object: nil)

        gotoPageNotificationObserver = NotificationCenter.default.addObserver(forName: PDFViewerViewController.PDFGoToPageNotification.name, object: nil, queue: OperationQueue.main) { [weak self] (notification) in
            if let page = notification.object as? PDFPage {
                self?.pdfView.go(to: page)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        parent?.navigationController?.hidesBarsOnTap = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        parent?.navigationController?.hidesBarsOnTap = false
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let hideThumbnails = self.navigationController!.isNavigationBarHidden
        if hideThumbnails {
            self.thumbnailViewPosition = .none
        } else {
            self.thumbnailViewPosition = .bottom
        }
        pdfView.scaleFactor = pdfView.scaleFactorForSizeToFit
        pdfView.autoScales = true
    }

    func save(item: OCItem) {
        editingDelegate?.save(item: item, fileURL: source)
    }

    // MARK: - Handlers for PDF View notifications

    @objc func handlePageChanged() {
        updatePageLabel()
    }

    // MARK: - Toolbar actions

    @objc func goToPage() {

        guard let pdfDocument = pdfView.document else { return }

        let alertMessage = NSString(format: "This document has %@ pages".localized as NSString, "\(pdfDocument.pageCount)") as String
        let alertController = UIAlertController(title: "Go to page".localized, message: alertMessage, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel, handler: nil))

        alertController.addTextField(configurationHandler: { textField in
            textField.placeholder = "Page".localized
            textField.keyboardType = .decimalPad
        })

        alertController.addAction(UIAlertAction(title: "OK".localized, style: .default, handler: { [unowned self] _ in
            if let pageLabel = alertController.textFields?.first?.text {
                self.selectPage(with: pageLabel)
            }
        }))

        self.present(alertController, animated: true)
    }

    @objc func search() {
        guard let pdfDocument = pdfView.document else { return }

        let pdfSearchController = PDFSearchViewController()
        let searchNavigationController = ThemeNavigationController(rootViewController: pdfSearchController)
        pdfSearchController.pdfDocument = pdfDocument
        pdfSearchController.userSelectedMatchCallback = { (selection) in
            DispatchQueue.main.async {
                selection.color = UIColor.yellow
                self.pdfView.setCurrentSelection(selection, animate: true)
                self.pdfView.scrollSelectionToVisible(nil)

                DispatchQueue.main.asyncAfter(deadline: .now() + self.searchAnnotationDelay, execute: {
                    self.pdfView.clearSelection()
                })
            }
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            searchNavigationController.modalPresentationStyle = .popover
            searchNavigationController.popoverPresentationController?.barButtonItem = searchButtonItem
        }

        self.present(searchNavigationController, animated: true)
    }

    @objc func showOutline() {
        guard let pdfDocument = pdfView.document else { return }

        let outlineViewController = PDFOutlineViewController()
        let searchNavigationController = ThemeNavigationController(rootViewController: outlineViewController)
        outlineViewController.pdfDocument = pdfDocument

        if UIDevice.current.userInterfaceIdiom == .pad {
            searchNavigationController.modalPresentationStyle = .popover
            searchNavigationController.popoverPresentationController?.barButtonItem = outlineItem
        }

        self.present(searchNavigationController, animated: true)
    }

    // MARK: - Private helpers

    fileprivate func adjustThumbnailsSize() {
        let thumbnailSize = floor(min(thumbnailView.frame.size.height, thumbnailView.frame.size.width)) - 8.0
        if thumbnailSize > 0 {
            thumbnailView.thumbnailSize = CGSize(width: thumbnailSize, height: thumbnailSize)
        }
    }

    fileprivate func setupConstraints() {

        if thumbnailView.superview == nil || pdfView.superview == nil {
            return
        }

        let guide = view.safeAreaLayoutGuide

        var constraints = [NSLayoutConstraint]()
        constraints.append(containerView.topAnchor.constraint(equalTo: guide.topAnchor))

        thumbnailView.isHidden = false

        switch thumbnailViewPosition {
        case .left:
            constraints.append(thumbnailView.topAnchor.constraint(equalTo: guide.topAnchor))
            constraints.append(thumbnailView.leadingAnchor.constraint(equalTo: guide.leadingAnchor))
            constraints.append(thumbnailView.bottomAnchor.constraint(equalTo: guide.bottomAnchor))
            constraints.append(thumbnailView.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: thumbnailViewWidthMultiplier))

            constraints.append(containerView.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor))
            constraints.append(containerView.trailingAnchor.constraint(equalTo: guide.trailingAnchor))
            constraints.append(containerView.bottomAnchor.constraint(equalTo: guide.bottomAnchor))

        case .right:
            constraints.append(thumbnailView.topAnchor.constraint(equalTo: guide.topAnchor))
            constraints.append(thumbnailView.leadingAnchor.constraint(equalTo: containerView.trailingAnchor))
            constraints.append(thumbnailView.trailingAnchor.constraint(equalTo: guide.trailingAnchor))
            constraints.append(thumbnailView.bottomAnchor.constraint(equalTo: guide.bottomAnchor))
            constraints.append(thumbnailView.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: thumbnailViewWidthMultiplier))

            constraints.append(containerView.leadingAnchor.constraint(equalTo: guide.leadingAnchor))
            constraints.append(containerView.trailingAnchor.constraint(equalTo: thumbnailView.leadingAnchor))
            constraints.append(containerView.bottomAnchor.constraint(equalTo: guide.bottomAnchor))

        case .bottom:
            constraints.append(thumbnailView.topAnchor.constraint(equalTo: containerView.bottomAnchor))
            constraints.append(thumbnailView.leadingAnchor.constraint(equalTo: guide.leadingAnchor))
            constraints.append(thumbnailView.trailingAnchor.constraint(equalTo: guide.trailingAnchor))
            constraints.append(thumbnailView.bottomAnchor.constraint(equalTo: guide.bottomAnchor))
            constraints.append(thumbnailView.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: thumbnailViewHeightMultiplier))

            constraints.append(containerView.leadingAnchor.constraint(equalTo: guide.leadingAnchor))
            constraints.append(containerView.trailingAnchor.constraint(equalTo: guide.trailingAnchor))
            constraints.append(containerView.bottomAnchor.constraint(equalTo: thumbnailView.topAnchor))

        case .none:
            constraints.append(containerView.leadingAnchor.constraint(equalTo: guide.leadingAnchor))
            constraints.append(containerView.trailingAnchor.constraint(equalTo: guide.trailingAnchor))
            constraints.append(containerView.bottomAnchor.constraint(equalTo: guide.bottomAnchor))
            thumbnailView.isHidden = true
        }

        self.activeViewConstraints = constraints

    }

    fileprivate func setupToolbar() {
        searchButtonItem = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(search))
        gotoButtonItem = UIBarButtonItem(image: UIImage(named: "ic_pdf_go_to_page"), style: .plain, target: self, action: #selector(goToPage))
        outlineItem = UIBarButtonItem(image: UIImage(named: "ic_pdf_outline"), style: .plain, target: self, action: #selector(showOutline))

        self.parent?.navigationItem.rightBarButtonItems = [
            gotoButtonItem!,
            searchButtonItem!,
            outlineItem!]
    }

    fileprivate func selectPage(with label:String) {
        guard let pdf = pdfView.document else { return }

        if let pageNr = Int(label) {
            if pageNr > 0 && pageNr < pdf.pageCount {
                if let page = pdf.page(at: pageNr - 1) {
                    self.pdfView.go(to: page)
                }
            }
        }
    }

    fileprivate func updatePageLabel() {
        guard let pdf = pdfView.document else { return }

        guard let currentPageLabel = pdfView.currentPage?.label else { return }

        pageCountLabel.text = "\(currentPageLabel) of \(pdf.pageCount)"
    }
}
