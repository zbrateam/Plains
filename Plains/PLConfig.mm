//
//  PLConfig.m
//  Plains
//
//  Created by Wilson Styres on 4/25/21.
//

#import "PLConfig.h"

#include "apt-pkg/pkgcache.h"
#include "apt-pkg/configuration.h"
#include "apt-pkg/init.h"
#include "apt-pkg/pkgsystem.h"

@implementation PLConfig

- (instancetype)init {
    self = [super init];
    
    if (self) {
        pkgInitConfig(*_config);
        pkgInitSystem(*_config, _system);
    }
    
    return self;
}

- (void)setString:(NSString *)string forKey:(NSString *)key {
    _config->Set(key.UTF8String, string.UTF8String);
}

- (void)setBoolean:(BOOL)boolean forKey:(NSString *)key {
    _config->Set(key.UTF8String, boolean);
}

- (void)setInteger:(int)integer forKey:(NSString *)key {
    _config->Set(key.UTF8String, integer);
}

- (NSString *)stringForKey:(NSString *)key {
    std::string result = _config->Find(key.UTF8String);
    if (!result.empty()) {
        return [NSString stringWithUTF8String:result.c_str()];
    }
    return NULL;
}

- (BOOL)booleanForKey:(NSString *)key {
    return _config->FindB(key.UTF8String);
}

- (int)integerForKey:(NSString *)key {
    return _config->FindI(key.UTF8String);
}

@end
