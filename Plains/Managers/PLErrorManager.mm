//
//  PLErrorManager.m
//  Plains
//
//  Created by Adam Demasi on 10/3/2022.
//

#import "PLErrorManager.h"
#import "NSString+Plains.h"
#import <Plains/Plains-Swift.h>
#import <os/lock.h>

PL_APT_PKG_IMPORTS_BEGIN
#import <apt-pkg/error.h>
PL_APT_PKG_IMPORTS_END

@implementation PLErrorManager {
    os_unfair_lock lock;
    NSMutableArray <PLError *> *_errorMessages;
}

@dynamic errorMessages;

+ (instancetype)sharedInstance {
    static PLErrorManager *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[PLErrorManager alloc] init];
    });
    return sharedInstance;
}

- (NSArray <PLError *> *)errorMessages {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        self->_errorMessages = [NSMutableArray array];
    });

    os_unfair_lock_lock(&lock);
    while (!_error->empty()) {
        std::string error;
        bool isError = _error->PopMessage(error);
        if (!error.empty()) {
            NSString *text = [NSString plains_stringWithStdString:error];
            // Ignore certain annoying warnings
            if (!isError && [text containsString:@"is configured multiple times in"]) {
                continue;
            }
            PLError *plainsError = [[PLError alloc] initWithLevel:isError ? PLErrorLevelError : PLErrorLevelWarning
                                                             text:text];
            [self->_errorMessages addObject:plainsError];
        }
    }
    NSArray <PLError *> *errorMessages = [self->_errorMessages copy];
    os_unfair_lock_unlock(&lock);
    return errorMessages;
}

- (NSUInteger)errorCountAtLevel:(PLErrorLevel)errorLevel {
    NSArray <PLError *> *errorMessages = self.errorMessages;
    NSUInteger count = 0;
    for (PLError *item in errorMessages) {
        if (item.level == errorLevel) {
            count += 1;
        }
    }
    return count;
}

- (void)clear {
    os_unfair_lock_lock(&lock);
    [self->_errorMessages removeAllObjects];
    os_unfair_lock_unlock(&lock);
}

@end
