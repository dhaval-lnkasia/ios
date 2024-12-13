//
//  ConfidentialManager.m
//  ownCloud
//
//  Created by Matthias Hühne on 09.12.24.
//  Copyright © 2024 ownCloud GmbH. All rights reserved.
//

/*
 * Copyright (C) 2024, ownCloud GmbH.
 *
 * This code is covered by the GNU Public License Version 3.
 *
 * For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 * You should have received a copy of this license along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 *
 */

#import "ConfidentialManager.h"

@implementation ConfidentialManager

+ (instancetype)sharedConfidentialManager
{
	static dispatch_once_t onceToken;
	static ConfidentialManager *sharedInstance;

	dispatch_once(&onceToken, ^{
		sharedInstance = [ConfidentialManager new];
	});

	return (sharedInstance);
}

#pragma mark - Class settings

+ (OCClassSettingsIdentifier)classSettingsIdentifier
{
	return (OCClassSettingsIdentifierConfidential);
}

- (BOOL)allowScreenshots {
	id value = [ConfidentialManager classSettingForOCClassSettingsKey:OCClassSettingsKeyAllowScreenshots];
	return value ? [value boolValue] : YES;
}

- (BOOL)markConfidentialViews {
	id value = [ConfidentialManager classSettingForOCClassSettingsKey:OCClassSettingsKeyMarkConfidentialViews];
	return value ? [value boolValue] : YES;
}

- (BOOL)allowOverwriteConfidentialMDMSettings {
	BOOL confidentialSettingsEnabled = self.confidentialSettingsEnabled;
	id value = [ConfidentialManager classSettingForOCClassSettingsKey:OCClassSettingsKeyAllowOverwriteConfidentialMDMSettings];
	return confidentialSettingsEnabled && (value ? [value boolValue] : YES);
}

- (BOOL)confidentialSettingsEnabled {
	return self.allowScreenshots || self.markConfidentialViews;
}

- (NSArray<NSString *> *)disallowedActions {
	if (self.confidentialSettingsEnabled && !self.allowOverwriteConfidentialMDMSettings) {
		return @[
			@"com.owncloud.action.openin",
			@"com.owncloud.action.copy",
			@"action.allow-image-interactions"
		];
	}
	return nil;
}

+ (NSDictionary<OCClassSettingsKey,id> *)defaultSettingsForIdentifier:(OCClassSettingsIdentifier)identifier
{
	if ([identifier isEqual:OCClassSettingsIdentifierConfidential]) {
		return @{
			OCClassSettingsKeyAllowScreenshots : @NO,
			OCClassSettingsKeyMarkConfidentialViews : @YES,
			OCClassSettingsKeyAllowOverwriteConfidentialMDMSettings : @NO
		};
	}
	return nil;
}

+ (OCClassSettingsMetadataCollection)classSettingsMetadata
{
	return (@{
		OCClassSettingsKeyAllowScreenshots : @{
			@"type" : @"boolean",
			@"description" : @"Controls whether screenshots are allowed or not. If not allowed confidential views will be marked as sensitive and are not visible in screenshots.",
			@"category" : @"Confidential",
			@"status" : @"debugOnly"
		},
		OCClassSettingsKeyMarkConfidentialViews : @{
			@"type" : @"boolean",
			@"description" : @"Controls if views which contains sensitive content contains a watermark or not.",
			@"category" : @"Confidential",
			@"status" : @"debugOnly"
		},
		OCClassSettingsKeyAllowOverwriteConfidentialMDMSettings : @{
			@"type" : @"boolean",
			@"description" : @"Controls if confidential related MDM settings can be overwritten.",
			@"category" : @"Confidential",
			@"status" : @"debugOnly"
		}
	});
}

@end

OCClassSettingsIdentifier OCClassSettingsIdentifierConfidential = @"confidential";

OCClassSettingsKey OCClassSettingsKeyAllowScreenshots = @"allow-screenshots";
OCClassSettingsKey OCClassSettingsKeyMarkConfidentialViews = @"mark-confidential-views";
OCClassSettingsKey OCClassSettingsKeyAllowOverwriteConfidentialMDMSettings = @"allow-overwrite-confidential-mdm-settings";
