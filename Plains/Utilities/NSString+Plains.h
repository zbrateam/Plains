//
//  NSString+Plains.h
//  Plains
//
//  Created by Wilson Styres on 5/11/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 Interface to compare to Debian package version.
 */
@interface NSString (Plains)

/*!
 Compare two NSStrings based on libapt's `debVersioningSystem`.
 */
- (NSComparisonResult)compareVersion:(NSString *)otherVersion;

@end

NS_ASSUME_NONNULL_END
