//
//  PLQueue.h
//  Plains
//
//  Created by Wilson Styres on 4/5/21.
//

#import <Foundation/Foundation.h>

@class PLPackage;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, PLQueueType) {
    PLQueueInstall,
    PLQueueRemove, 
};

@interface PLQueue : NSObject
+ (instancetype)sharedInstance;
- (BOOL)addPackage:(PLPackage *)package toQueue:(PLQueueType)queue;
@end

NS_ASSUME_NONNULL_END
