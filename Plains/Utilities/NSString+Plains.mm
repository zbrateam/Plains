//
//  NSString+Plains.m
//  Plains
//
//  Created by Wilson Styres on 5/11/21.
//

#import "NSString+Plains.h"

PL_APT_PKG_IMPORTS_BEGIN
#import <apt-pkg/debversion.h>
PL_APT_PKG_IMPORTS_END

@implementation NSString (Plains)

+ (instancetype)plains_stringWithStdString:(std::string)stdString {
    return [[self alloc] plains_initWithStdString:stdString];
}

- (instancetype)plains_initWithStdString:(std::string)stdString {
    return [self plains_initWithCString:stdString.c_str()];
}

- (NSString *)plains_initWithCString:(const char *)cString {
    if (cString != 0 && cString[0] != '\0') {
        return [NSString stringWithUTF8String:cString];
    }
    return nil;
}

- (NSComparisonResult)plains_compareVersion:(NSString *)otherVersion {
    if (!otherVersion) return NSOrderedDescending;
    
    const char *A = self.UTF8String;
    const char *B = otherVersion.UTF8String;
    const char *AEnd = &A[strlen(A)];
    const char *BEnd = &B[strlen(B)];
    
    debVersioningSystem vs = debVersioningSystem();
    int result = vs.DoCmpVersion(A, AEnd, B, BEnd);
    if (result < 0)
        return NSOrderedAscending;
    if (result > 0)
        return NSOrderedDescending;
    return NSOrderedSame;
}

@end
