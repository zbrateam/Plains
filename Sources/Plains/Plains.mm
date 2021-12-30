//
//  Plains.m
//  
//
//  Created by Aarnav Tale on 12/28/21.
//

#import <apt-pkg/acquire.h>
#import "Include/Header.h"

@implementation PLDummyTest
- (NSString *)concatenate:(NSString *)string {
	auto cpp_string = std::string("test");
	return [NSString stringWithFormat:@"%s %d", cpp_string.c_str(), APT_PKG_MAJOR];
}
@end
