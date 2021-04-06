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

- (instancetype)init {
    self = [super init];
    
    if (self) {
        database = [PLDatabase sharedInstance];
    }
    
    return self;
}

- (NSArray *)packages {
    NSMutableArray *packages = [NSMutableArray arrayWithCapacity:PLQueueCount - 1];
    for (int i = 0; i < PLQueueCount; i++) {
        packages[i] = [NSMutableArray new];
    }
    
    pkgCacheFile &cache = database.cache;
    for (PLPackage *package in database.packages) {
        pkgCache::PkgIterator iterator = package.iterator;
        pkgDepCache::StateCache &state = cache[iterator];
        
        if (state.NewInstall()) {
            [packages[PLQueueInstall] addObject:package];
        } else if (state.Delete()) {
            [packages[PLQueueRemove] addObject:package];
        }
    }
    
    return packages;
}

- (BOOL)addPackage:(PLPackage *)package toQueue:(PLQueueType)queue {
    PLDatabase *database = [PLDatabase sharedInstance];
    pkgCacheFile &cache = [database cache];
    pkgProblemResolver *resolver = [database resolver];
    pkgCache::PkgIterator iterator = package.iterator;
    
    switch (queue) {
        case PLQueueInstall: {
            NSLog(@"[Plains] Installing %@", package.name);
            resolver->Clear(iterator);
            resolver->Protect(iterator);
            
            cache->SetReInstall(iterator, false);
            cache->MarkInstall(iterator, true);
            break;
        }
        case PLQueueRemove: {
            NSLog(@"[Plains] Removing %@", package.name);
            resolver->Clear(iterator);
            resolver->Remove(iterator);
            resolver->Protect(iterator);
            
            cache->MarkDelete(iterator, true);
            break;
        }
        default:
            break;
    }
    
    resolver->Resolve();
    
    return YES;
}

@end
