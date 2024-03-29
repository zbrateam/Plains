//
//  PLQueue.m
//  Plains
//
//  Created by Wilson Styres on 4/5/21.
//

#import "PLQueue.h"

#import <Plains/Plains.h>

PL_APT_PKG_IMPORTS_BEGIN
#import <apt-pkg/algorithms.h>
#import <apt-pkg/indexfile.h>
PL_APT_PKG_IMPORTS_END

NSNotificationName const PLQueueUpdateNotification = @"PLQueueUpdateNotification";

@implementation PLQueue {
    PLPackageManager *database;
    NSMutableDictionary <NSString *, NSSet *> *enqueuedDependencies;
}

@synthesize issues = _issues;
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
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(generatePackages) name:PLDatabaseRefreshNotification object:nil];
    }
    
    return self;
}

- (void)generatePackages {
    _hasEssentialPackages = NO;
    
    NSMutableArray *packages = [NSMutableArray arrayWithCapacity:PLQueueCount - 1];
    NSMutableDictionary *issues = [NSMutableDictionary new];
    for (NSUInteger i = 0; i < PLQueueCount; i++) {
        packages[i] = [NSMutableArray new];
    }
    
    pkgCacheFile &cache = database.cache;
    for (PLPackage *package in database.packages) {
        pkgCache::PkgIterator iterator = package.package;
        
        if (cache[iterator].InstBroken()) {
            pkgCache::VerIterator installedVersionIterator = cache[iterator].InstVerIter(cache);
            if (installedVersionIterator.end()) continue;
            
            pkgCache::DepIterator depIterator = installedVersionIterator.DependsList();
            while (!depIterator.end()) {
                pkgCache::DepIterator Start;
                pkgCache::DepIterator End;
                depIterator.GlobOr(Start, End); // Iterates over entire dependency group instead of just one dependency apparently the "more sensible" way to iterate, also increments depIterator.
                
                if ((cache[End] & pkgDepCache::DepGInstall) != 0) continue; // Is this dependency actually broken?
                
                while (true) {
                    PLBrokenReason reason;
                    NSString *installedVersion;
                    pkgCache::PkgIterator target = Start.TargetPkg();
                    if (target->ProvidesList != NULL) { // Package cannot be found in current sources.
                        reason = PLBrokenReasonNotFound;
                    } else {
                        pkgCache::VerIterator installedTargetVersion = cache[target].InstVerIter(cache);
                        if (!installedTargetVersion.end()) { // The installed version is different than the required version (and is likely missing)
                            reason = PLBrokenReasonAlreadyInstalled;
                            installedVersion = [NSString stringWithUTF8String:installedTargetVersion.VerStr()];
                        } else { // I'm sure there are other cases but I have no idea ATM
                            reason = PLBrokenReasonUnknown;
                        }
                    }
                    
                    NSDictionary *issue = @{
                        @"reason": @(reason),
                        @"relationship": [NSString stringWithUTF8String:Start.DepType()],
                        @"target": [NSString stringWithUTF8String:Start.TargetPkg().Name()],
                        @"comparison": [NSString stringWithUTF8String:Start.CompType()],
                        @"requiredVersion": [NSString stringWithUTF8String:Start.TargetVer()],
                        @"installedVersion": installedVersion
                    };
                    
                    NSArray *newIssues = issues[package.identifier] ?: @[];
                    issues[package.identifier] = [newIssues arrayByAddingObject:issue];
                    
                    if (Start == End) break;
                    Start++;
                }
            }
        }
        
        pkgDepCache::StateCache &state = cache[iterator];
        if (state.NewInstall()) {
            [packages[PLQueueInstall] addObject:package];
        } else if (state.Upgrade()) {
            [packages[PLQueueUpgrade] addObject:package];
        } else if (state.Downgrade()) {
            [packages[PLQueueDowngrade] addObject:package];
        } else if (state.ReInstall()) {
            [packages[PLQueueReinstall] addObject:package];
        } else if (state.Delete()) {
            if (!_hasEssentialPackages && package.isEssential) _hasEssentialPackages = YES;
            [packages[PLQueueRemove] addObject:package];
        }
    }
    
    _issues = issues;
    _queuedPackages = packages;
}

- (NSDictionary *)issues {
    if (_issues) return _issues;
    
    [self generatePackages];
    return _issues;
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
    
    _count = 0;
    for (NSArray *arr in _queuedPackages) {
        _count += arr.count;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PLQueueUpdateNotification object:nil userInfo:@{@"count": @(_count)}];
}

- (void)addPackage:(PLPackage *)package toQueue:(PLQueueType)queue {
    PLPackageManager *database = [PLPackageManager sharedInstance];
    pkgCacheFile &cache = [database cache];
    pkgProblemResolver *resolver = [database resolver];
    pkgCache::PkgIterator iterator = package.package;
    
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
        case PLQueueDowngrade: {
            cache->SetCandidateVersion(package.verIterator);
            cache->MarkInstall(iterator, false);
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
    pkgCache::PkgIterator iterator = package.package;
    
    resolver->Clear(iterator);
    
    cache->MarkKeep(iterator, false);
    
    for (PLPackage *dependency in enqueuedDependencies[package.identifier]) {
        pkgCache::PkgIterator dependencyIterator = dependency.package;
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
            pkgCache::PkgIterator iterator = package.package;
            
            resolver->Clear(iterator);
            cache->MarkKeep(iterator, false);
        }
    }
    
    [self resolve];
}

- (void)queueLocalPackage:(NSURL *)url {
    PLPackage *local = [[PLPackageManager sharedInstance] addDebFile:url error:nil];
    if (local) {
        [self addPackage:local toQueue:PLQueueInstall];
    }
}

@end
