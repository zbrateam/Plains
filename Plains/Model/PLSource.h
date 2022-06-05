//
//  PLSource.h
//  Plains
//
//  Created by Wilson Styres on 3/1/21.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
typedef struct metaIndex metaIndex;
#endif

NS_ASSUME_NONNULL_BEGIN

/*!
 Mainly an Objective-C interface for `metaIndex` but also provides useful methods that are used in the iOS darwin system.
 */
NS_SWIFT_NAME(Source)
@interface PLSource : NSObject

#pragma mark - Init

#ifdef __cplusplus
/*!
 Default initializer.
 */
- (instancetype)initWithMetaIndex:(metaIndex *)index;
#endif

#pragma mark - State

/*!
 The current pin preference of this source.
 */
@property (nonatomic) short defaultPin;

/*!
 Whether or not the source is marked as "trusted" by libapt.
 */
@property (nonatomic) BOOL trusted;

#ifdef __cplusplus
/*!
 The base metaIndex object that represents this source.
 */
@property (nonatomic) metaIndex *index;
#endif

/*!
 The location of the file this source originates from.
 */
@property (nonatomic, strong) NSString *entryFilePath;

/*!
 Warnings or errors that are specific to this source.
 */
@property (nonatomic, strong) NSArray <NSString *> *messages;

#pragma mark - Meta

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

#pragma mark - Fields

/*!
 Get a custom field from the package's control file

 @param field The custom field to be retrieved.
 @return The value of that field or `NULL` if the field does not exist.
 */
- (nullable NSString *)getField:(NSString *)field;

/*!
 The source's archive type.
 */
@property (nonatomic, strong) NSString *type;

/*!
 The source's codename.
 */
@property (nonatomic, strong) NSString *codename;

/*!
 The source's suite.
 */
@property (nonatomic, strong) NSString *suite;

/*!
 Any components that the source has.
 */
@property (nonatomic, strong) NSArray <NSString *> *components;

/*!
 Architectures the repository provides packages for.
 */
@property (nonatomic, strong) NSArray <NSString *> *architectures;

/*!
 The source's distribution.
 */
@property (nonatomic, strong) NSString *distribution;

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
 The source's release notes.
 */
@property (nonatomic, strong) NSString *releaseNotes;

#pragma mark - Packages

/*!
 A dictionary representing a readout of all packages hosted by the source.

 Each key is a section name and each value is the number of packages in that section.

 Packages without a section are labeled as "Uncategorized".
 */
@property (readonly) NSDictionary <NSString *, NSNumber *> *sections;

@end

NS_ASSUME_NONNULL_END
