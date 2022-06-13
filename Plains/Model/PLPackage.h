//
//  PLPackage.h
//  Plains
//
//  Created by Wilson Styres on 3/4/21.
//

#import <Foundation/Foundation.h>

#import <Plains/Plains.h>

#ifdef __cplusplus
PL_APT_PKG_IMPORTS_BEGIN
#include <apt-pkg/cachefile.h>
#include <apt-pkg/pkgrecords.h>
PL_APT_PKG_IMPORTS_END
#endif

@class PLSource, PLEmail;

NS_ASSUME_NONNULL_BEGIN

/*!
 Mainly an Objective-C interface for `pkgcache::PkgIterator` but also provides useful methods that are used in the iOS darwin system.
 */
NS_SWIFT_NAME(Package)
@interface PLPackage : NSObject

#pragma mark - Init

#ifdef __cplusplus
/*!
 Initialize a package object.

 - parameter iterator: The package's version iterator.
 - parameter depCache: The cache that the package is a member of.
 - parameter records: The records file that the package exists in.
 - returns: A new PLPackage instance.
 */
- (id)initWithIterator:(pkgCache::VerIterator)iterator depCache:(pkgDepCache *)depCache records:(pkgRecords *)records;

/*!
 The underlying candidate version of the libapt package object.

 - returns: An iterator representing the package as a whole.
 */
@property (nonatomic, readonly) pkgCache::PkgIterator package;

/*!
 The underlying libapt package object.

 - returns: An iterator representing this specific package.
 */
@property (nonatomic, readonly) pkgCache::VerIterator verIterator;
#endif

#pragma mark - State

/*!
 Whether or not the package is installed on the user's device.
 */
@property (readonly) BOOL isInstalled;

/*!
 Whether or not this package is marked as essential and should not be removed.

 Specified by a package's `Essential` field.
 */
@property (readonly) BOOL isEssential;

/*!
 Whether or not a package has been held back from updates.

 Packages that are held will not display in the updates section if an update is available.
 */
@property (nonatomic) BOOL isHeld;

#pragma mark - Versions

/*!
 Whether or not the package has an update.

 - returns: `true` if the package has an update and is not held back, `false` otherwise.
 */
@property (nonatomic, readonly) BOOL hasUpdate;

/*!
 The installed version of a package, if installed.
 */
@property (nonatomic, strong, readonly, nullable) NSString *installedVersion;

/*!
 The total number of available versions that exist for this package.

 - returns: The number of versions for this package.
 */
@property (nonatomic, readonly) NSUInteger numberOfVersions;

/*!
 All versions that exist for this package.

 - returns: An array of PLPackage objects representing all available versions of this package.
 */
@property (nonatomic, strong, readonly) NSArray <PLPackage *> *allVersions;

#pragma mark - Relationships

/*!
 The source that the package is from or `NULL` if the package's source no longer exists.

 - returns: The source that the package is from.
 */
@property (nonatomic, strong, readonly, nullable) PLSource *source;

#pragma mark - Fields

/*!
 Get a custom field from the package's control file

 - parameter field: The custom field to be retrieved.
 - returns: The value of that field or `NULL` if the field does not exist.
 */
- (nullable NSString *)getField:(NSString *)field;

/*!
 The package's identifier.

 Specified by a package's `Package` field.
 */
@property (nonatomic, strong, readonly) NSString *identifier;

/*!
 The package's architecture.

 Specified by a package's `Architecture` field.
 */
@property (nonatomic, strong, readonly) NSString *architecture;

/*!
 The package's author.

 Specified by a package's `Author` field in an RFC822 format.
 */
@property (nonatomic, strong, nullable, readonly) PLEmail *author;

/*!
 The package's maintainer.

 Specified by a package's `Maintainer` field in an RFC822 format.
 */
@property (nonatomic, strong, nullable, readonly) PLEmail *maintainer;

/*!
 The download size, if available, of the package.
 
 Specified by a package's `Size` field.
 */
@property (nonatomic, readonly) NSUInteger downloadSize;

/*!
 The size of a package's contents once installed on the device.

 Specified by a package's `Installed-Size` field.
 */
@property (nonatomic, readonly) NSUInteger installedSize;

/*!
 The first line of a package's description. Usually kept short and sweet.
 
 Specified by a package's `Description` field.
 */
@property (nonatomic, strong, readonly) NSString *shortDescription;

/*!
 The package's version.
 
 Specified by a package's `Version` field.
 */
@property (nonatomic, strong, readonly) NSString *version;

/*!
 A longer description of the package that provides more detail than the shortDescription.
 
 Specified by a package's `Description` field if there is more than one line.
 
 - returns: The longDescription  or `NULL` if the homepage does not exist.
 */
@property (nonatomic, strong, readonly, nullable) NSString *longDescription;

@property (nonatomic, strong, readonly) NSArray <NSString *> *tags;

@end

NS_ASSUME_NONNULL_END
