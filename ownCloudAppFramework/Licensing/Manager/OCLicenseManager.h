//
//  OCLicenseManager.h
//  ownCloudApp
//
//  Created by Felix Schwarz on 29.10.19.
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

#import <Foundation/Foundation.h>
#import <ownCloudSDK/ownCloudSDK.h>
#import "OCLicenseTypes.h"

NS_ASSUME_NONNULL_BEGIN

@class OCLicenseFeature;
@class OCLicenseProvider;
@class OCLicenseProduct;
@class OCLicenseOffer;
@class OCLicenseObserver;

@interface OCLicenseManager : NSObject

@property(strong,nonatomic,class,readonly) OCLicenseManager *sharedLicenseManager;

@property(strong,nonatomic,readonly) OCAsyncSequentialQueue *queue;

#pragma mark - Feature/product registration
- (void)registerFeature:(OCLicenseFeature *)feature; //!< Register a feature with the license manager
- (void)registerProduct:(OCLicenseProduct *)product; //!< Register a product with the license manager

#pragma mark - Feature/product resolution
- (nullable OCLicenseProduct *)productWithIdentifier:(OCLicenseProductIdentifier)productIdentifier; //!< Returns the product for the passed identifier - or nil if none with that identifier was found.
- (nullable OCLicenseFeature *)featureWithIdentifier:(OCLicenseFeatureIdentifier)featureIdentifier; //!< Returns the feature for the passed identifier - or nil if none with that identifier was found.

- (nullable NSArray<OCLicenseOffer *> *)offersForFeature:(OCLicenseFeature *)feature; //!< Returns an array of offers for products containing that feature, sorted by price.
- (nullable NSArray<OCLicenseOffer *> *)offersForProduct:(OCLicenseProduct *)product; //!< Returns an array of offers for the product, sorted by price.

#pragma mark - Provider management
- (void)addProvider:(OCLicenseProvider *)provider; //!< Add an entitlement and offer provider to the license manager
- (void)removeProvider:(OCLicenseProvider *)provider; //!< Remove an entitlement and offer provider from the license manager

#pragma mark - Observation
- (OCLicenseObserver *)observeProducts:(nullable NSArray<OCLicenseProductIdentifier> *)productIdentifiers features:(nullable NSArray<OCLicenseFeatureIdentifier> *)featureIdentifiers inEnvironment:(OCLicenseEnvironment *)environment withOwner:(nullable id)owner updateHandler:(OCLicenseObserverAuthorizationStatusUpdateHandler)updateHandler; //!< Starts observing the authorization status of the products and features identified by their respective identifiers, in the passed environment. The passed .updateHandler will be called whenever the authorization status changes. An owner to which only a weak reference is stored can be passed for convenience. If the owner is deallocated, the observation will stop automatically. 
- (OCLicenseObserver *)observeOffersForProducts:(nullable NSArray<OCLicenseProductIdentifier> *)productIdentifiers features:(nullable NSArray<OCLicenseFeatureIdentifier> *)featureIdentifiers withOwner:(nullable id)owner updateHandler:(OCLicenseObserverOffersUpdateHandler)updateHandler; //!< Starts observing offers covering the provided products and features. The passed .updateHandler will be called whenever the offers change. An owner to which only a weak reference is stored can be passed for convenience. If the owner is deallocated, the observation will stop automatically.

- (void)stopObserver:(OCLicenseObserver *)observer;

@end

NS_ASSUME_NONNULL_END
