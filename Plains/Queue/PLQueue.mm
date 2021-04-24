//
//  PLQueue.m
//  Plains
//
//  Created by Wilson Styres on 4/5/21.
//

#import "PLQueue.h"

#import <Plains/PLPackageManager.h>
#import <Plains/PLPackage.h>

#include "apt-pkg/algorithms.h"

NSString *const PLQueueUpdateNotification = @"PlainsQueueUpdate";

@implementation PLQueue

@synthesize queuedPackages = _queuedPackages;

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
        database = [PLPackageManager sharedInstance];
        enqueuedDependencies = [NSMutableDictionary new];
    }
    
    return self;
}

- (void)generatePackages {
    NSMutableArray *packages = [NSMutableArray arrayWithCapacity:PLQueueCount - 1];
    for (int i = 0; i < PLQueueCount; i++) {
        packages[i] = [NSMutableArray new];
    }
    
    pkgCacheFile &cache = database.cache;
    for (PLPackage *package in database.packages) {
        pkgCache::PkgIterator iterator = package.iterator;
        pkgDepCache::StateCache &state = cache[iterator];
        
        if (cache[iterator].InstBroken()) {
            NSLog(@"[Plains] %@ would be broken after this install.", package.name);
        }
        
        if (state.NewInstall()) {
            [packages[PLQueueInstall] addObject:package];
        } else if (state.Upgrade()) {
            [packages[PLQueueUpgrade] addObject:package];
        } else if (state.ReInstall()) {
            [packages[PLQueueReinstall] addObject:package];
        } else if (state.Delete()) {
            [packages[PLQueueRemove] addObject:package];
        }
    }
    
    _queuedPackages = packages;
}

- (NSArray *)queuedPackages {
    if (_queuedPackages) return _queuedPackages;
    
    [self generatePackages];
    return _queuedPackages;
}

- (void)resolve {
    pkgProblemResolver *resolver = [database resolver];
    
    resolver->Resolve();
    
    [self generatePackages];
    
    NSUInteger count = 0;
    for (NSArray *arr in _queuedPackages) {
        count += arr.count;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PLQueueUpdateNotification object:nil userInfo:@{@"count": @(count)}];
}

- (void)addPackage:(PLPackage *)package toQueue:(PLQueueType)queue {
    PLPackageManager *database = [PLPackageManager sharedInstance];
    pkgCacheFile &cache = [database cache];
    pkgProblemResolver *resolver = [database resolver];
    pkgCache::PkgIterator iterator = package.iterator;
    
    resolver->Clear(iterator);
    resolver->Protect(iterator);
    switch (queue) {
        case PLQueueUpgrade:
        case PLQueueInstall: {
            cache->MarkInstall(iterator, false);
            break;
        }
        case PLQueueRemove: {
            cache->MarkDelete(iterator, true);
            break;
        }
        case PLQueueReinstall: {
            cache->SetReInstall(iterator, true);
            break;
        }
        default:
            break;
    }
    
    NSMutableSet *beforeIdentifiers = [NSMutableSet new];
    for (NSArray *queue in _queuedPackages) {
        for (PLPackage *queuedPackage in queue) {
            [beforeIdentifiers addObject:queuedPackage];
        }
    }
    [self resolve];
    
    NSMutableSet *afterIdentifiers = [NSMutableSet new];
    for (NSArray *queue in _queuedPackages) {
        for (PLPackage *queuedPackage in queue) {
            [afterIdentifiers addObject:queuedPackage];
        }
    }
    
    [afterIdentifiers minusSet:beforeIdentifiers];
    [afterIdentifiers removeObject:package];
    
    enqueuedDependencies[package.identifier] = afterIdentifiers;
}

- (BOOL)canRemovePackage:(PLPackage *)package {
    return enqueuedDependencies[package.identifier] != NULL;
}

- (void)removePackage:(PLPackage *)package {
    PLPackageManager *database = [PLPackageManager sharedInstance];
    pkgCacheFile &cache = [database cache];
    pkgProblemResolver *resolver = [database resolver];
    pkgCache::PkgIterator iterator = package.iterator;
    
    resolver->Clear(iterator);
    
    cache->MarkKeep(iterator, false);
    
    for (PLPackage *dependency in enqueuedDependencies[package.identifier]) {
        pkgCache::PkgIterator dependencyIterator = dependency.iterator;
        resolver->Clear(dependencyIterator);
        
        cache->MarkKeep(dependencyIterator, false);
    }
    
    [self resolve];
}

- (void)clear {
    PLPackageManager *database = [PLPackageManager sharedInstance];
    pkgCacheFile &cache = [database cache];
    pkgProblemResolver *resolver = [database resolver];
    
    for (NSArray *queue in _queuedPackages) {
        for (PLPackage *package in queue) {
            pkgCache::PkgIterator iterator = package.iterator;
            
            resolver->Clear(iterator);
            cache->MarkKeep(iterator, false);
        }
    }
    
    [self resolve];
}

@end