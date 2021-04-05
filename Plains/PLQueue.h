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

typedef NS_ENUM(NSUInteger, PLQueueType) {
    PLQueueInstall,
    PLQueueRemove,
    PLQueueCount,
};

@interface PLQueue : NSObject {
    PLDatabase *database;
}
+ (instancetype)sharedInstance;
- (NSArray *)packages;
- (BOOL)addPackage:(PLPackage *)package toQueue:(PLQueueType)queue;
@end

NS_ASSUME_NONNULL_END
