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
    PLQueueInstall,
    PLQueueRemove,
    PLQueueReinstall,
    PLQueueUpgrade,
    PLQueueDowngrade,
    PLQueueCount,
};

typedef NS_ENUM(NSUInteger, PLBrokenReason) {
    PLBrokenReasonNotFound,
    PLBrokenReasonAlreadyInstalled,
    PLBrokenReasonUnknown
};

@interface PLQueue : NSObject {
    PLPackageManager *database;
    NSMutableDictionary <NSString *, NSSet *> *enqueuedDependencies;
}
@property (nonatomic, readonly) NSDictionary <NSString *, NSArray *> *issues;
@property (nonatomic, readonly) NSArray *queuedPackages;
@property (nonatomic, readonly) int count;
+ (instancetype)sharedInstance;
- (NSArray *)queuedPackages;
- (void)addPackage:(PLPackage *)package toQueue:(PLQueueType)queue;
- (BOOL)canRemovePackage:(PLPackage *)package;
- (void)removePackage:(PLPackage *)package;
- (void)clear;
@end

NS_ASSUME_NONNULL_END
