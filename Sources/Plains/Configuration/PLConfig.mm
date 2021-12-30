//
//  PLConfig.m
//  Plains
//
//  Created by Wilson Styres on 4/25/21.
//

#import "PLConfig.h"

#include <apt-pkg/pkgcache.h>
#include <apt-pkg/configuration.h>
#include <apt-pkg/init.h>
#include <apt-pkg/pkgsystem.h>
#include <apt-pkg/error.h>

@implementation PLConfig

+ (instancetype)sharedInstance {
    static PLConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [PLConfig new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        pkgInitConfig(*_config);
        pkgInitSystem(*_config, _system);
        
//        // Some extra config options if you'd like to debug Plains w/ Charles
//        _config->Set("Acquire::http::Proxy", "http://localhost:8888");
//        _config->Set("Acquire::http::Verify-Peer", false);
//        _config->Set("Acquire::http::Verify-Host", false);
//        _config->Set("Acquire::https::Verify-Peer", false);
//        _config->Set("Acquire::https::Verify-Host", false);
    }
    
    return self;
}

- (void)clearErrors {
    [self->errorMessages removeAllObjects];
    _error->Discard();
}

- (NSArray <NSString *> *)errorMessages {
    if (!self->errorMessages) self->errorMessages = [NSMutableArray new];
    while (!_error->empty()) {
        std::string error;
        _error->PopMessage(error);
        if (!error.empty()) {
            NSString *message = [NSString stringWithUTF8String:error.c_str()];
            [self->errorMessages addObject:message];
        }
    }
    return self->errorMessages;
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
