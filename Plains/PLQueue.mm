//
//  PLQueue.m
//  Plains
//
//  Created by Wilson Styres on 4/5/21.
//

#import "PLQueue.h"

#import <Plains/PLDatabase.h>
#import <Plains/PLPackage.h>

#include "apt-pkg/algorithms.h"

@implementation PLQueue

+ (instancetype)sharedInstance {
    static PLQueue *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [PLQueue new];
    });
    return instance;
}

- (BOOL)addPackage:(PLPackage *)package toQueue:(PLQueueType)queue {
    pkgCacheFile cache = [[PLDatabase sharedInstance] cache];
    pkgProblemResolver *resolver = new pkgProblemResolver(cache);
    pkgCache::PkgIterator iterator = package.iterator;
    
    switch (queue) {
        case PLQueueInstall: {
            break;
        }
        case PLQueueRemove: {
            resolver->Clear(iterator);
            resolver->Remove(iterator);
            resolver->Protect(iterator);
            
            cache->MarkDelete(iterator);
            break;
        }
    }
    
    return YES;
}

@end
