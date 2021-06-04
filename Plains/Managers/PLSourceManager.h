//
//  PLSourceManager.h
//  Plains
//
//  Created by Wilson Styres on 4/15/21.
//

#import <Foundation/Foundation.h>

#include "apt-pkg/sourcelist.h"

@class PLSource;
@class PLPackage;

NS_ASSUME_NONNULL_BEGIN

/*!
 Notification constant representing that a source refresh has started.
 */
extern NSString *const PLStartedSourceRefreshNotification;

/*!
 Notification constant representing that a source has started downloading.
 */
extern NSString *const PLStartedSourceDownloadNotification;

/*!
 Notification constant representing that a source has finished downloading.
 */
extern NSString *const PLFinishedSourceDownloadNotification;

/*!
 Notification constant representing that a source has failed to acquire one of its files.
 */
extern NSString *const PLFailedSourceDownloadNotification;

/*!
 Notification constant representing that a source refresh has finished,
 */
extern NSString *const PLFinishedSourceRefreshNotification;

/*!
 Notification constant representing that the source list has been updated.
 */
extern NSString *const PLSourceListUpdatedNotification;

/*!
 Manages sources and the relations with the internal libapt pkgSourceList.
 
 @warning This class should only be accessed through its `sharedInstance`
 */
@interface PLSourceManager : NSObject

/*!
 Returns the shared `PLSourceManager` instance, creating it if necessary.
 
 @return The shared `PLSourceManager` instance.
 */
+ (instancetype)sharedInstance;

/*!
 Triggers a source refresh.
 */
- (void)refreshSources;

/*!
 List of PLSource objects representing the sources that libapt keeps track of.
 
 @warning PLSource objects may or may not be complete depending on available caches.
 @return An array of PLSource objects.
 */
- (NSArray <PLSource *> *)sources;

/*!
 Adds a source to the file designated by `Plains::SourcesList`.
 
 @param archiveType The archive type of the source. Can be either `deb` or `deb-src`.
 @param URI The URI of the repository.
 @param distribution The repository's distribution.
 @param components The repository's components, if applicable.
 */
- (void)addSourceWithArchiveType:(NSString *)archiveType repositoryURI:(NSString *)URI distribution:(NSString *)distribution components:(NSArray <NSString *> *_Nullable)components;

/*!
 Add several sources in bulk only triggering a source list refresh once all sources have been added.
 
 @param sources An array of NSDictionarys that contain `archiveType`, `repositoryURI`, `distribution`, and `components`.
 */
- (void)addSources:(NSArray <NSDictionary *> *)sources;

/*!
 Removes a source from the list file designated by `Plains::SourcesList`.
 
 @param sourceToRemove The source to remove.
 */
- (void)removeSource:(PLSource *)sourceToRemove;

/*!
 Get the source that a package is from.
 
 @param package The package that you want the source for.
 @return The source that the package is a member of or `NULL` if no such source exists.
 */
- (PLSource *)sourceForPackage:(PLPackage *)package;

/*!
 Get a the instance of a source from a corresponding UUID.
 
 @param UUID The UUID of the source you want to search for.
 @return The source instance with a matching UUID or `NULL` if no such source exists.
 */
- (PLSource *)sourceForUUID:(NSString *)UUID;
@end

NS_ASSUME_NONNULL_END
