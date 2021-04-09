//
//  PLDatabase.m
//  Plains
//
//  Created by Wilson Styres on 2/27/21.
//

#import "PLDatabase.h"

#import "PLSource.h"
#import "PLPackage.h"

#include "apt-pkg/pkgcache.h"
#include "apt-pkg/init.h"
#include "apt-pkg/pkgsystem.h"
#include "apt-pkg/sourcelist.h"
#include "apt-pkg/metaindex.h"
#include "apt-pkg/update.h"
#include "apt-pkg/acquire.h"
#include "apt-pkg/debindexfile.h"
#include "apt-pkg/error.h"

@interface PLDatabase () {
    pkgSourceList *sourceList;
    pkgCacheFile cache;
    pkgProblemResolver *resolver;
    NSArray *sources;
    NSArray *packages;
    NSArray *updates;
    BOOL cacheOpened;
    BOOL refreshing;
    NSMutableDictionary <NSNumber *, PLSource *> *packageSourceMap;
}
@end

NSString *const PLDatabaseUpdateNotification = @"PlainsDatabaseUpdate";

@implementation PLDatabase

+ (void)load {
    [super load];
    
    pkgInitConfig(*_config);
    pkgInitSystem(*_config, _system);
    
    _config->Set("Acquire::AllowInsecureRepositories", true);
    
#if TARGET_OS_MACCATALYST
    _config->Set("Debug::pkgProblemResolver", true);
    _config->Set("Dir::Log", "/Users/wstyres/Library/Caches/xyz.willy.Zebra/logs");
    _config->Set("Dir::State::Lists", "/Users/wstyres/Library/Caches/xyz.willy.Zebra/lists");
#else
    _config->Set("Dir::Log", "/var/mobile/Library/Caches/xyz.willy.Zebra/logs");
    _config->Set("Dir::State::Lists", "/var/mobile/Library/Caches/xyz.willy.Zebra/lists");
    _config->Set("Dir::Bin::dpkg", "/usr/libexec/zebra/supersling");
#endif
}

+ (instancetype)sharedInstance {
    static PLDatabase *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [PLDatabase new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self->sourceList = new pkgSourceList();
        self->packageSourceMap = [NSMutableDictionary new];
    }
    
    return self;
}

- (pkgCacheFile &)cache {
    [self openCache];
    return self->cache;
}

- (pkgProblemResolver *)resolver {
    [self openCache];
    return self->resolver;
}

- (BOOL)openCache {
    if (cacheOpened) return true;
    
    while (!_err->empty()) _err->Discard();
    
    BOOL result = cache.Open(NULL, false);
    if (!result) {
        while (!_err->empty()) {
            std::string error;
            bool warning = !_err->PopMessage(error);
            
            NSLog(@"[Plains] %@ while opening cache: %s", warning ? @"Warning" : @"Error", error.c_str());
        }
    }
    
    resolver = new pkgProblemResolver(self->cache);
    cacheOpened = result;
    return result;
}

- (void)closeCache {
    if (cacheOpened) {
        cache.Close();
        cacheOpened = false;
    }
}

- (void)import {
    [self readSourcesFromList:self->sourceList];
    [self importAllPackages];
}

- (void)refreshSources {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self readSourcesFromList:self->sourceList];
        
        pkgAcquire fetcher = pkgAcquire(NULL);
        if (fetcher.GetLock(_config->FindDir("Dir::State::Lists")) == false)
            return;

        // Populate it with the source selection
        if (self->sourceList->GetIndexes(&fetcher) == false)
            return;

        AcquireUpdate(fetcher, 0, true);

        while (!_err->empty()) { // Not sure AcquireUpdate() actually throws errors but i assume it does
            std::string error;
            bool warning = !_err->PopMessage(error);

            printf("%s\n", error.c_str());
        }
        
        [self importAllPackages];
    });
}

- (void)readSourcesFromList:(pkgSourceList *)sourceList {
    if (![self openCache]) return;
    
    self->sources = NULL;
    sourceList->ReadMainList();
    
    NSMutableArray *tempSources = [NSMutableArray new];
    for (pkgSourceList::const_iterator iterator = sourceList->begin(); iterator != sourceList->end(); iterator++) {
        metaIndex *index = *iterator;
        PLSource *source = [[PLSource alloc] initWithMetaIndex:index];
        
        std::vector<pkgIndexFile *> *indexFiles = index->GetIndexFiles();
        for (std::vector<pkgIndexFile *>::const_iterator iterator = indexFiles->begin(); iterator != indexFiles->end(); iterator++) {
            debPackagesIndex *packagesIndex = (debPackagesIndex *)*iterator;
            if (packagesIndex != NULL) {
                pkgCache::PkgFileIterator package = (*packagesIndex).FindInCache(cache);
                if (!package.end()) {
                    packageSourceMap[@(package->ID)] = source;
                }
            }
        }
        
        [tempSources addObject:source];
    }
    
    self->sources = tempSources;
}

- (void)importAllPackages {
    if (![self openCache]) return;
    
    self->packages = NULL;
    
    pkgDepCache *depCache = cache.GetDepCache();
    pkgRecords *records = new pkgRecords(*depCache);
    
    NSMutableArray *packages = [NSMutableArray arrayWithCapacity:depCache->Head().PackageCount];
    NSMutableArray *updates = [NSMutableArray arrayWithCapacity:16];
    for (pkgCache::PkgIterator iterator = depCache->PkgBegin(); !iterator.end(); iterator++) {
        PLPackage *package = [[PLPackage alloc] initWithIterator:iterator depCache:depCache records:records];
        if (package) [packages addObject:package];
        if (package.hasUpdate) [updates addObject:package];
    }
    self->packages = packages;
    self->updates = updates;
    
    if (self->updates.count) [[NSNotificationCenter defaultCenter] postNotificationName:PLDatabaseUpdateNotification object:nil userInfo:@{@"count": @(self->updates.count)}];
}

- (NSArray <PLSource *> *)sources {
    if (!self->sources || self->sources.count == 0) {
        [self readSourcesFromList:self->sourceList];
    }
    return self->sources;
}

- (NSArray <PLPackage *> *)packages {
    if (!self->packages || self->packages.count == 0) {
        [self importAllPackages];
    }
    return self->packages;
}

- (NSArray <PLPackage *> *)updates {
    return self->updates;
}

- (void)fetchPackagesMatchingFilter:(BOOL (^)(PLPackage *package))filter completion:(void (^)(NSArray <PLPackage *> *packages))completion {
    NSMutableArray *filteredPackages = [NSMutableArray new];
    for (PLPackage *package in self.packages) {
        if (filter(package)) {
            [filteredPackages addObject:package];
        }
    }
    [filteredPackages sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
    completion(filteredPackages);
}

- (PLSource *)sourceFromID:(unsigned long)identifier {
//    NSLog(@"[Plains] IDentifier: %lu", identifier);
    PLSource *source = packageSourceMap[@(identifier)];
    return source; // If a source isn't found return the local repository (later)
}

@end
