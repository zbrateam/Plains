//
//  PLDatabase.h
//  Plains
//
//  Created by Wilson Styres on 2/27/21.
//

#import <Foundation/Foundation.h>

@class PLSource;
@class PLPackage;

NS_ASSUME_NONNULL_BEGIN

@interface PLDatabase : NSObject

+ (instancetype)sharedInstance;
- (void)refreshSources;
- (NSArray <PLSource *> *)sources;
- (NSArray <PLPackage *> *)packages;

@end

NS_ASSUME_NONNULL_END
