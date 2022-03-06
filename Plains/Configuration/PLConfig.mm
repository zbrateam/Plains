//
//  PLConfig.m
//  Plains
//
//  Created by Wilson Styres on 4/25/21.
//

#import "PLConfig.h"

PL_APT_PKG_IMPORTS_BEGIN
#include "apt-pkg/pkgcache.h"
#include "apt-pkg/configuration.h"
#include "apt-pkg/init.h"
#include "apt-pkg/pkgsystem.h"
#include "apt-pkg/error.h"
PL_APT_PKG_IMPORTS_END

@implementation PLConfig {
    NSMutableArray <NSString *> *_errorMessages;
}

+ (instancetype)sharedInstance {
    static PLConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [PLConfig new];
    });
    return instance;
}

- (BOOL)initializeAPT {
    if (!pkgInitConfig(*_config)) {
        NSLog(@"[Plains] pkgInitConfig failed: %@", self.errorMessages);
        return NO;
    }
    if (!pkgInitSystem(*_config, _system)) {
        NSLog(@"[Plains] pkgInitSystem failed: %@", self.errorMessages);
        return NO;
    }

//    // Some extra config options if you'd like to debug Plains w/ Charles
//    _config->Set("Acquire::http::Proxy", "http://localhost:8888");
//    _config->Set("Acquire::http::Verify-Peer", false);
//    _config->Set("Acquire::http::Verify-Host", false);
//    _config->Set("Acquire::https::Verify-Peer", false);
//    _config->Set("Acquire::https::Verify-Host", false);

    return YES;
}

- (void)clearErrors {
    [self->_errorMessages removeAllObjects];
    _error->Discard();
}

- (NSArray <NSString *> *)errorMessages {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        self->_errorMessages = [NSMutableArray array];
    });

    while (!_error->empty()) {
        std::string error;
        _error->PopMessage(error);
        if (!error.empty()) {
            NSString *message = [NSString stringWithUTF8String:error.c_str()];
            [self->_errorMessages addObject:message];
        }
    }
    return self->_errorMessages;
}

- (NSString *)stringForKey:(NSString *)key {
    std::string result = _config->Find(key.UTF8String);
    if (!result.empty()) {
        return [NSString stringWithUTF8String:result.c_str()];
    }
    return NULL;
}

- (void)setString:(NSString *)string forKey:(NSString *)key {
    _config->Set(key.UTF8String, string.UTF8String);
}

- (BOOL)booleanForKey:(NSString *)key {
    return _config->FindB(key.UTF8String);
}

- (void)setBoolean:(BOOL)boolean forKey:(NSString *)key {
    _config->Set(key.UTF8String, boolean);
}

- (int)integerForKey:(NSString *)key {
    return _config->FindI(key.UTF8String);
}

- (void)setInteger:(int)integer forKey:(NSString *)key {
    _config->Set(key.UTF8String, integer);
}

@end
