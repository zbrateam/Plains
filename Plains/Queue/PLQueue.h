//
//  PLQueue.h
//  Plains
//
//  Created by Wilson Styres on 4/5/21.
//

#import <Foundation/Foundation.h>

@class PLPackageManager;
@class PLPackage;

NS_ASSUME_NONNULL_BEGIN

/*!
 Notification constant representing that the queue has been updated.
 */
extern NSString* const PLQueueUpdateNotification;

/*!
 Enumerated types to represent the different queues.
 */
typedef NS_ENUM(NSUInteger, PLQueueType) {
    PLQueueInstall,
    PLQueueRemove,
    PLQueueReinstall,
    PLQueueUpgrade,
    PLQueueDowngrade,
    PLQueueCount,
};

/*!
 Enumerated types to represent why a package might be broken.
 */
typedef NS_ENUM(NSUInteger, PLBrokenReason) {
    PLBrokenReasonNotFound,
    PLBrokenReasonAlreadyInstalled,
    PLBrokenReasonUnknown
};

/*!
 Objective-C interface for problem resolving and keeping track of which packages are queued.
 
 @warning This class should only be accessed through its `sharedInstance`
 */
@interface PLQueue : NSObject {
    PLPackageManager *database;
    NSMutableDictionary <NSString *, NSSet *> *enqueuedDependencies;
}

/*!
 A dictionary of issues that might have arisen due to different packages being queued together.
 
 Keys are package identifiers and the value is an array of dictionaries representing the problems.
 */
@property (nonatomic, readonly) NSDictionary <NSString *, NSArray *> *issues;

/*!
 An array of arrays containing the packages that are queued.
 
 Each index can be represented by a PLQueueType.
 */
@property (nonatomic, readonly) NSArray *queuedPackages;

/*!
 The number of packages currently in the queue.
 */
@property (nonatomic, readonly) int count;

/*!
 Whether or not the queue currently has essential packages queued for removal.
 */
@property (nonatomic, readonly) BOOL hasEssentialPackages;

/*!
 Returns the shared `PLQueue` instance, creating it if necessary.
 
 @return The shared `PLQueue` instance.
 */
+ (instancetype)sharedInstance;

/*!
 Queue a local package for installation.
 
 @param url The URL where the local .deb is located.
 */
- (void)queueLocalPackage:(NSURL *)url;

/*!
 Add a package to the queue.
 
 @param package The package to be queued.
 @param queue The queue to add the package to.
 */
- (void)addPackage:(PLPackage *)package toQueue:(PLQueueType)queue;

/*!
 Whether or not a package can be removed from the queue.
 
 Packages that have been queued directly by the user can be removed, dependencies or conflict removals cannot be removed.
 
 @param package The package to check the removal status of.
 */
- (BOOL)canRemovePackage:(PLPackage *)package;

/*!
 Remove a package from the queue.
 
 @param package The package to remove from the queue.
 */
- (void)removePackage:(PLPackage *)package;

/*!
 Clear the entire queue.
 */
- (void)clear;
@end

NS_ASSUME_NONNULL_END
