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

extern NSString* const PLQueueUpdateNotification;

typedef NS_ENUM(NSUInteger, PLQueueType) {
    PLQueueIssues,
    PLQueueInstall,
    PLQueueRemove,
    PLQueueReinstall,
    PLQueueUpgrade,
    PLQueueDowngrade,
    PLQueueCount,
};

@interface PLQueue : NSObject {
    PLPackageManager *database;
    NSMutableDictionary <NSString *, NSSet *> *enqueuedDependencies;
}
@property (nonatomic, readonly) NSArray *queuedPackages;
+ (instancetype)sharedInstance;
- (NSArray *)queuedPackages;
- (void)addPackage:(PLPackage *)package toQueue:(PLQueueType)queue;
- (BOOL)canRemovePackage:(PLPackage *)package;
- (void)removePackage:(PLPackage *)package;
- (void)clear;
@end

NS_ASSUME_NONNULL_END
