//
//  PLConfig.m
//  Plains
//
//  Created by Wilson Styres on 4/25/21.
//

#import "PLConfig.h"
#import "PLErrorManager.h"
#import "NSString+Plains.h"

PL_APT_PKG_IMPORTS_BEGIN
#import <apt-pkg/pkgcache.h>
#import <apt-pkg/configuration.h>
#import <apt-pkg/init.h>
#import <apt-pkg/pkgsystem.h>
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
        NSLog(@"[Plains] pkgInitConfig failed: %@", [PLErrorManager sharedInstance].errorMessages);
        return NO;
    }
    if (!pkgInitSystem(*_config, _system)) {
        NSLog(@"[Plains] pkgInitSystem failed: %@", [PLErrorManager sharedInstance].errorMessages);
        return NO;
    }
    return YES;
}

- (NSString *)stringForKey:(NSString *)key {
    return [NSString plains_stringWithStdString:_config->Find(key.UTF8String)];
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

- (NSURL *)fileURLForKey:(NSString *)key {
    NSString *result = [NSString plains_stringWithStdString:_config->FindFile(key.UTF8String)];
    if (result) {
        return [NSURL fileURLWithPath:result isDirectory:NO];
    }
    return nil;
}

- (void)removeObjectForKey:(NSString *)key {
    _config->Clear(key.UTF8String);
}

@end
