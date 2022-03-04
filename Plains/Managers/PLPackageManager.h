//
//  PLPackageManager.h
//  Plains
//
//  Created by Wilson Styres on 2/27/21.
//

#import <Foundation/Foundation.h>

#import <Plains/Delegates/PLConsoleDelegate.h>

#ifndef SWIFT
#include "apt-pkg/cachefile.h"
#include "apt-pkg/algorithms.h"
#include "apt-pkg/sourcelist.h"
#endif

@class PLSource;
@class PLPackage;

NS_ASSUME_NONNULL_BEGIN

/*!
 Notification constant that indicates when the database has been initially imported.
 */
extern NSNotificationName const PLDatabaseImportNotification NS_SWIFT_NAME(PLPackageManager.databaseDidImportNotification);

/*!
 Notification constant that indicates when the database has been refreshed after being initially imported.
 */
extern NSNotificationName const PLDatabaseRefreshNotification NS_SWIFT_NAME(PLPackageManager.databaseDidRefreshNotification);

extern NSString* const PLErrorDomain;

extern NSInteger const PLPackageManagerErrorGeneral;
extern NSInteger const PLPackageManagerErrorInvalidDebFile;
extern NSInteger const PLPackageManagerErrorInvalidDebControl;

/*!
 Manages packages and the relations with the internal libapt pkgCache.
 
 @warning This class should only be accessed through its `sharedInstance`
 */
@interface PLPackageManager : NSObject

/*!
 Returns the shared `PLPackageManager` instance, creating it if necessary.
 
 @return The shared `PLPackageManager` instance.
 */
@property (nonatomic, strong, readonly, class) PLPackageManager *sharedInstance NS_SWIFT_NAME(shared);

#ifndef SWIFT
/*!
 The internal package cache file used by libapt, opening it if necessary.
 */
- (pkgCacheFile &)cache;

/*!
 The internal package problem resolver object used by libapt.
 */
- (pkgProblemResolver *_Nullable)resolver;
#endif

/*!
 Reads packages from libapt's cache and imports them into PLPackage objects that can be accessed through the `packages` property.
 
 This method will also collect packages that have updates and store them in the `updates` property.
 
 If the cache has already been opened prior to calling `import`, a temporary cache will be opened and imported and then switched over to when the import is complete.
 */
- (void)import;

/*!
 All packages that are tracked by libapt's cache stored as PLPackage objects.
 
 @return An array of PLPackage objects.
 */
@property (nonatomic, strong, readonly) NSArray <PLPackage *> *packages;

/*!
 Packages that have an available update or are pinned by a repository and the installed version is not the version pinned.
 
 @return An array of PLPackage objects
 */
@property (nonatomic, strong, readonly) NSArray <PLPackage *> *updates;

/*!
 Filter the `packages` array for packages that match a certain filter.
 
 @param filter A block to check whether or not a given package matches the filter.
 @param completion Block that is run whenever the filter is complete with the entire filtered array.
 */
- (void)fetchPackagesMatchingFilter:(BOOL (^)(PLPackage *package))filter completion:(void (^)(NSArray <PLPackage *> *packages))completion;

/*!
 Starts the process of downloading and installing packages that have been queued.
 
 @param delegate A class that conforms to the `PLConsoleDelegate` protocol that is sent messages about the download/install progress.
 */
- (void)downloadAndPerform:(id<PLConsoleDelegate>)delegate NS_SWIFT_NAME(downloadAndPerform(delegate:));

/*!
 Perform a prefix search on package names.
 
 @param prefix The prefix to search for.
 @param completion Completion block to be run when results are retrieved.
 */
- (void)searchForPackagesWithNamePrefix:(NSString *)prefix completion:(void (^)(NSArray <PLPackage *> *packages))completion;

/*!
 Perform a full search for any packages whose name contains `name`.
 
 @param name The name to search for.
 @param completion Completion block to be run when results are retrieved.
 */
- (void)searchForPackagesWithName:(NSString *)name completion:(void (^)(NSArray <PLPackage *> *packages))completion;

/*!
 Perform a full search for any packages whose description contains `description`.
 
 @param description The description to search for.
 @param completion Completion block to be run when results are retrieved.
 */
- (void)searchForPackagesWithDescription:(NSString *)description completion:(void (^)(NSArray <PLPackage *> *packages))completion;

/*!
 Perform a full search for any packages whose author name  contains `authorName`.
 
 @param authorName The author name to search for.
 @param completion Completion block to be run when results are retrieved.
 */
- (void)searchForPackagesWithAuthorName:(NSString *)authorName completion:(void (^)(NSArray <PLPackage *> *packages))completion;

/*!
 Get the candidate version of a package. This is set to the package's latest available version by default but can be overridden (in the case of a package being downgraded)
 
 @param package The package to retrieve the candidate version of
 @return The candidate version string of `package`
 */
- (NSString *)candidateVersionForPackage:(PLPackage *)package;

/*!
 Finds a valid instance of a package that has been invalidated (possibly by a cache refresh)
 
 @param package The invalidated package to find
 @return The found package or `NULL` if no such package exists anymore
 */
- (PLPackage *_Nullable)findPackage:(PLPackage *)package;

/*!
 Adds a local .deb file as a source in the cache.
 
 @param path An NSURL representing the location of the .deb. file
 @param error An NSError representing the error loading the file, if any.
 @return A PLPackage instance of the added .deb file or `NULL` if the file could not be added.
 */
- (PLPackage *_Nullable)addDebFile:(NSURL *)url error:(NSError **)error;

/*!
 Modify a package's held state.
 
 Packages that are held will not be displayed as having an available update and will be listed as "held back" in the command line.
 
 @param package The package to modify the held state of.
 @param held `true` if the package is to be held, false otherwise.
 */
- (void)setPackage:(PLPackage *)package held:(BOOL)held;
@end

NS_ASSUME_NONNULL_END
