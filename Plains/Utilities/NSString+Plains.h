//
//  NSString+Plains.h
//  Plains
//
//  Created by Wilson Styres on 5/11/21.
//

#import <Foundation/Foundation.h>

#ifdef __cplusplus
#include <string>
#endif

NS_ASSUME_NONNULL_BEGIN

/*!
 Interface to compare to Debian package version.
 */
@interface NSString (Plains)

#ifdef __cplusplus
+ (instancetype)plains_stringWithStdString:(std::string)stdString;

- (instancetype)plains_initWithStdString:(std::string)stdString;
#endif

- (NSString *)plains_initWithCString:(const char *)cString NS_SWIFT_UNAVAILABLE("");

/*!
 Compare two NSStrings based on libapt's `debVersioningSystem`.
 */
- (NSComparisonResult)plains_compareVersion:(NSString *)otherVersion NS_SWIFT_NAME(compareVersion(_:));

@end

NS_ASSUME_NONNULL_END
