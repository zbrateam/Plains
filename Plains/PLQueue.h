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
    PLQueueCount,
};

@interface PLQueue : NSObject {
    PLDatabase *database;
    NSUInteger queueCount;
}
+ (instancetype)sharedInstance;
- (NSArray *)packages;
- (void)addPackage:(PLPackage *)package toQueue:(PLQueueType)queue;
- (void)removePackage:(PLPackage *)package;
@end

NS_ASSUME_NONNULL_END
