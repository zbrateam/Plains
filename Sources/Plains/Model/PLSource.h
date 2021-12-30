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
@property NSString *UUID;

/*!
 The source's base URI without components or distribution.
 */
@property NSURL *baseURI;

/*!
 The source's full URL.
 */
@property NSURL *URI;

/*!
 The source's distribution.
 */
@property NSString *distribution;

/*!
 The source's archive type.
 */
@property NSString *type;

/*!
 The source's origin.
 */
@property (nonatomic) NSString *origin;

/*!
 The source's label.
 */
@property NSString *label;

/*!
 The source's version.
 */
@property NSString *version;

/*!
 The source's codename.
 */
@property NSString *codename;

/*!
 The source's suite.
 */
@property NSString *suite;

/*!
 The source's release notes.
 */
@property NSString *releaseNotes;

/*!
 A dictionary representing a readout of all packages hosted by the source.
 
 Each key is a section name and each value is the number of packages in that section.
 
 Packages without a section are labeled as "Uncategorized".
 */
@property (readonly) NSDictionary *sections;

/*!
 The current pin preference of this source.
 */
@property short defaultPin;

/*!
 Whether or not the source is marked as "trusted" by libapt.
 */
@property BOOL trusted;

/*!
 The base metaIndex object that represents this source.
 */
@property metaIndex *index;

/*!
 The location of the file this source originates from.
 */
@property NSString *entryFilePath;

/*!
 Any components that the source has.
 */
@property NSArray *components;

/*!
 Warnings or errors that are specific to this source.
 */
@property NSArray *messages;

/*!
 Default initializer.
 */
- (id)initWithMetaIndex:(metaIndex *)index;

/*!
 URL of an image that can be used to represent this source.
 
 On iOS environments this will return `CydiaIcon.png` but on macOS environments this will return `RepoIcon.png`.
 */
- (NSURL *)iconURL;

/*!
 Whether or not this source can be removed by Plains.
 */
- (BOOL)canRemove;

/*!
 Equality comparison.
 */
- (BOOL)isEqualToSource:(PLSource *)other;

/*!
 Compare two sources by their origin (case insensitively).
 */
- (NSComparisonResult)compareByOrigin:(PLSource *)other;
@end

NS_ASSUME_NONNULL_END
