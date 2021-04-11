//
//  PLQueue.h
//  Plains
//
//  Created by Wilson Styres on 4/5/21.
//

#import <Foundation/Foundation.h>

@class PLDatabase;
@class PLPackage;

NS_ASSUME_NONNULL_BEGIN

extern NSString* const PLQueueUpdateNotification;

typedef NS_ENUM(NSUInteger, PLQueueType) {
    PLQueueInstall,
    PLQueueRemove,
    PLQueueReinstall,
    PLQueueUpgrade,
    PLQueueCount,
};

@interface PLQueue : NSObject {
    PLDatabase *database;
    NSMutableDictionary <NSString *, NSArray *> *enqueuedDependencies;
}
@property (nonatomic, readonly) NSArray *queuedPackages;
+ (instancetype)sharedInstance;
- (NSArray *)queuedPackages;
- (void)addPackage:(PLPackage *)package toQueue:(PLQueueType)queue;
- (BOOL)canRemovePackage:(PLPackage *)package;
- (void)removePackage:(PLPackage *)package;
@end

NS_ASSUME_NONNULL_END
