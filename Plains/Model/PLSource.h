//
//  PLSource.h
//  Plains
//
//  Created by Wilson Styres on 3/1/21.
//

#import <Foundation/Foundation.h>

@class UIImage;

typedef struct metaIndex metaIndex; // Some sort of tricky forward declaring metaIndex because theos doesn't like #include

NS_ASSUME_NONNULL_BEGIN

/*!
 Mainly an Objective-C interface for `metaIndex` but also provides useful methods that are used in the iOS darwin system.
 */
@interface PLSource : NSObject

/*!
 The source's unique identifier.
 
 Based on the repository URI, distribution, and components.
 */
@property (nonatomic, strong) NSString *UUID;

/*!
 The source's base URI without components or distribution.
 */
@property (nonatomic, strong) NSURL *baseURI;

/*!
 The source's full URL.
 */
@property (nonatomic, strong) NSURL *URI;

/*!
 The source's distribution.
 */
@property (nonatomic, strong) NSString *distribution;

/*!
 The source's archive type.
 */
@property (nonatomic, strong) NSString *type;

/*!
 The source's origin.
 */
@property (nonatomic, strong) NSString *origin;

/*!
 The source's label.
 */
@property (nonatomic, strong) NSString *label;

/*!
 The source's version.
 */
@property (nonatomic, strong) NSString *version;

/*!
 The source's codename.
 */
@property (nonatomic, strong) NSString *codename;

/*!
 The source's suite.
 */
@property (nonatomic, strong) NSString *suite;

/*!
 The source's release notes.
 */
@property (nonatomic, strong) NSString *releaseNotes;

/*!
 A dictionary representing a readout of all packages hosted by the source.
 
 Each key is a section name and each value is the number of packages in that section.
 
 Packages without a section are labeled as "Uncategorized".
 */
@property (readonly) NSDictionary <NSString *, NSNumber *> *sections;

/*!
 The current pin preference of this source.
 */
@property (nonatomic) short defaultPin;

/*!
 Whether or not the source is marked as "trusted" by libapt.
 */
@property (nonatomic) BOOL trusted;

/*!
 The base metaIndex object that represents this source.
 */
@property (nonatomic) metaIndex *index;

/*!
 The location of the file this source originates from.
 */
@property (nonatomic, strong) NSString *entryFilePath;

/*!
 Any components that the source has.
 */
@property (nonatomic, strong) NSArray <NSString *> *components;

/*!
 Architectures the repository provides packages for.
 */
@property (nonatomic, strong) NSArray <NSString *> *architectures;

/*!
 Warnings or errors that are specific to this source.
 */
@property (nonatomic, strong) NSArray <NSString *> *messages;

/*!
 Default initializer.
 */
- (instancetype)initWithMetaIndex:(metaIndex *)index;

/*!
 URL of an image that can be used to represent this source.
 
 For iphoneos-arm repositories this will return `CydiaIcon.png`, otherwise this will return `RepoIcon.png`.
 */
@property (nonatomic, strong, readonly) NSURL *iconURL;

/*!
 Whether or not this source can be removed by Plains.
 */
@property (nonatomic, readonly) BOOL canRemove;

/*!
 Equality comparison.
 */
- (BOOL)isEqual:(PLSource *)other;

/*!
 Compare two sources by their origin (case insensitively).
 */
- (NSComparisonResult)compareByOrigin:(PLSource *)other;

@end

NS_ASSUME_NONNULL_END
