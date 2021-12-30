//
//  PLPackage.h
//  Plains
//
//  Created by Wilson Styres on 3/4/21.
//

#import <Foundation/Foundation.h>

#include <apt-pkg/cachefile.h>
#include <apt-pkg/pkgrecords.h>

@class PLSource;

NS_ASSUME_NONNULL_BEGIN

/*!
 Mainly an Objective-C interface for `pkgcache::PkgIterator` but also provides useful methods that are used in the iOS darwin system.
 */
@interface PLPackage : NSObject

/*!
 The name of the package's author in an RFC822 format..
 */
@property (nonatomic, nullable) NSString *authorName;

/*!
 The email of the package's author.
 
 Specified by a package's `Author` field in an RFC822 format.
 */
@property (nonatomic, nullable) NSString *authorEmail;

/*!
 The download size, if available, of the package.
 
 Specified by a package's `Size` field.
 */
@property (nonatomic) NSUInteger downloadSize;

/*!
 The URL of an icon that can be displayed to represent the package.
 
 Specified by a package's `Icon` field.
 
 This URL can be local or remote.
 */
@property (nonatomic, nullable) NSURL * iconURL;

/*!
 The package's identifier
 
 Specified by a package's `Package` field.
 */
@property (nonatomic) NSString *identifier;

/*!
 The size of a package's contents once installed on the device.
 
 Specified by a package's `Installed-Size` field.
 */
@property (nonatomic) NSUInteger installedSize;

/*!
 The installed version of a package, if installed.
 */
@property (nonatomic, nullable) NSString *installedVersion;

/*!
 The package's name.
 
 Specified by a package's `Name` field or `Package` field if no `Name` field is present.
 */
@property (nonatomic) NSString *name;

/*!
 The role of a package.
 
 Specified by a package's `Tag` field.
 
 Acceptable roles (prefixed by role::) are:
 - `user` or `enduser` == 1
 - `hacker` == 2
 - `developer` == 3
 - `cydia` == 5
 
 Unrecognized roles will be assigned a role of 4. If a package does not have a role, it is assigned a role of 0.
 */
@property (nonatomic) uint16_t role;

/*!
 The package's section.
 
 Specified by a package's `Section` field.
 */
@property (nonatomic) NSString *section;

/*!
 The first line of a package's description. Usually kept short and sweet.
 
 Specified by a package's `Description` field.
 */
@property (nonatomic) NSString *shortDescription;

/*!
 The package's version.
 
 Specified by a package's `Version` field.
 */
@property (nonatomic) NSString *version;

/*!
 Whether or not the package is installed on the user's device.
 */
@property (readonly) BOOL installed;

/*!
 Whether or not the package requires payment.
 
 Specified by a package's `Tag` field, more specifically whether or not it has a `cydia::commercial` tag.
 */
@property (readonly) BOOL paid;

/*!
 Whether or not this package is marked as essential and should not be removed.
 
 Specified by a package's `Essential` field.
 */
@property (readonly) BOOL essential;

/*!
 Whether or not a package has been held back from updates.
 
 Packages that are held will not display in the updates section if an update is available.
 */
@property (nonatomic) BOOL held;

/*!
 Initialize a package object.
 
 @param iterator The package's version iterator.
 @param depCache The cache that the package is a member of.
 @param records The records file that the package exists in.
 @return A new PLPackage instance.
 */
- (id)initWithIterator:(pkgCache::VerIterator)iterator depCache:(pkgDepCache *)depCache records:(pkgRecords *)records;

/*!
 Get a custom field from the package's control file
 
 @param field The custom field to be retrieved.
 @return The value of that field or `NULL` if the field does not exist.
 */
- (NSString *_Nullable)getField:(NSString *)field;

/*!
 The source that the package is from or `NULL` if the package's source no longer exists.
 
 @return The source that the package is from.
 */
- (PLSource *)source;

/*!
 The package's installed size in the form of a string
 
 @return A formatted string (with units) indicating the package's installed size.
 */
- (NSString *)installedSizeString;

/*!
 The package's download size in the form of a string
 
 @return A formatted string (with units) indicating the package's download size.
 */
- (NSString *)downloadSizeString;

/*!
 Whether or not the package has an update.
 
 @return `true` if the package has an update and is not held back, `false` otherwise.
 */
- (BOOL)hasUpdate;

/*!
 Whether or not the package has a tagline.
 
 @return `true` if the package has both a short and long description, `false` otherwise.
 */
- (BOOL)hasTagline;

/*!
 The underlying candidate version of the libapt package object.
 
 @return An iterator representing the package as a whole.
 */
- (pkgCache::PkgIterator)iterator;

/*!
 The underlying libapt package object.
 
 @return An iterator representing this specific package.
 */
- (pkgCache::VerIterator)verIterator;

/*!
 The total number of available versions that exist for this package.
 
 @return The number of versions for this package.
 */
- (NSUInteger)numberOfVersions;

/*!
 All versions that exist for this package.
 
 @return An array of PLPackage objects representing all available versions of this package.
 */
- (NSArray <PLPackage *> *)allVersions;

/*!
 Versions of this package that are lesser than itself.
 
 @return An array of PLPackage objects representing all available lesser versions of this package.
 */
- (NSArray <PLPackage *> *)lesserVersions;

/*!
 Versions of this package that are greater than itself.
 
 @return An array of PLPackage objects representing all available greater versions of this package.
 */
- (NSArray <PLPackage *> *)greaterVersions;

/*!
 Files that this package has installed to the user's device.
 
 @return An array of strings representing file paths that are installed by this package onto the user's device. If the package is not installed, `NULL` is returned.
 */
- (NSArray <NSString *> *_Nullable)installedFiles;

/*!
 The URL of a web-based depiction to display to provide more information about the package
 
 Specified by a package's `Depiction` field.
 
 @return The depiction URL or `NULL` if the depiction does not exist.
 */
- (NSURL *_Nullable)depictionURL;

/*!
 The URL of a native depiction to be displayed with DepictionKit to provide more information about the package
 
 Specified by a package's `Native-Depiction` field.
 
 @return The native depiction URL or `NULL` if the native depiction does not exist.
 */
- (NSURL *_Nullable)nativeDepictionURL;

/*!
 The URL of the package's homepage to provide more information about it.
 
 Specified by a package's `Homepage` field.
 
 @return The homepage URL or `NULL` if the homepage does not exist.
 */
- (NSURL *_Nullable)homepageURL;

/*!
 A longer description of the package that provides more detail than the shortDescription.
 
 Specified by a package's `Description` field if there is more than one line.
 
 @return The longDescription  or `NULL` if the homepage does not exist.
 */
- (NSString *_Nullable)longDescription;

/*!
 The name of the package's maintainer.
 
 Specified by a package's `Maintainer` field in an RFC822 format.
 
 @return The maintainer's name or `NULL` if it does not exist.
 */
- (NSString *_Nullable)maintainerName;

/*!
 The email of the package's maintainer.
 
 Specified by a package's `Maintainer` field in an RFC822 format.
 
 @return The maintainer's email or `NULL` if it does not exist.
 */
- (NSString *_Nullable)maintainerEmail;

/*!
 The package's dependencies.
 
 Specified by a package's `Depends` field.
 
 @return An array of strings representing a package's dependencies or `NULL` if there are none.
 */
- (NSArray <NSString *> *_Nullable)depends;

/*!
 The package's conflicts.
 
 Specified by a package's `Conflicts` field.
 
 @return An array of strings representing a package's conflicts or `NULL` if there are none.
 */
- (NSArray <NSString *> *_Nullable)conflicts;

/*!
 The package's dependencies
 
 Specified by a package's `Depends` field.
 
 @return An array of strings representing a package's dependencies or `NULL` if there are none.
 */
- (NSURL *_Nullable)headerURL;
@end

NS_ASSUME_NONNULL_END
