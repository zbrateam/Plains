//
//  PLDatabase.h
//  Plains
//
//  Created by Wilson Styres on 2/27/21.
//

#import <Foundation/Foundation.h>

@class PLSource;

NS_ASSUME_NONNULL_BEGIN

@interface PLDatabase : NSObject

- (NSArray <PLSource *> *)sources;

@end

NS_ASSUME_NONNULL_END
