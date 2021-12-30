//
//  NSString+Plains.m
//  Plains
//
//  Created by Wilson Styres on 5/11/21.
//

#import "NSString+Plains.h"

#include <apt-pkg/debversion.h>

@implementation NSString (Plains)

- (NSComparisonResult)compareVersion:(NSString *)otherVersion {
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
