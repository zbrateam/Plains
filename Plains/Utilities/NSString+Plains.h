//
//  NSString+Plains.h
//  Plains
//
//  Created by Wilson Styres on 5/11/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSString (Plains)

- (NSComparisonResult)compareVersion:(NSString *)otherVersion;

@end

NS_ASSUME_NONNULL_END
