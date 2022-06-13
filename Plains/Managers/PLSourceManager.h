//
//  PLSourceManager.h
//  Plains
//
//  Created by Wilson Styres on 4/15/21.
//

#import <Foundation/Foundation.h>

@class PLSource, PLPackage;

NS_ASSUME_NONNULL_BEGIN

/*!
 Manages sources and the relations with the internal libapt pkgSourceList.
 
 - warning: This class should only be accessed through its `sharedInstance`
 */
NS_SWIFT_NAME(SourceManager)
@interface PLSourceManager : NSObject

/*!
 Returns the shared `PLSourceManager` instance, creating it if necessary.
 
 - returns: The shared `PLSourceManager` instance.
 */
@property (nonatomic, strong, readonly, class) PLSourceManager *sharedInstance NS_SWIFT_NAME(shared);

/*!
 Rebuild APT caches after a source update.
 */
- (BOOL)rebuildCache;

/*!
 List of PLSource objects representing the sources that libapt keeps track of.
 
 - warning: PLSource objects may or may not be complete depending on available caches.
 - returns: An array of PLSource objects.
 */
@property (nonatomic, strong, readonly) NSArray <PLSource *> *sources;

/*!
 Removes a source from the list file designated by `Plains::SourcesList`.
 
 - parameter sourceToRemove: The source to remove.
 */
- (void)removeSource:(PLSource *)sourceToRemove;

/*!
 Get the source that a package is from.
 
 - parameter package: The package that you want the source for.
 - returns: The source that the package is a member of or `NULL` if no such source exists.
 */
- (PLSource *)sourceForPackage:(PLPackage *)package;

// TODO: Private method
- (void)readSources;

@end

NS_ASSUME_NONNULL_END
