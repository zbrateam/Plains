//
//  PLDatabase.m
//  Plains
//
//  Created by Wilson Styres on 2/27/21.
//

#import "PLDatabase.h"

#import "PLSource.h"
#import "PLPackage.h"

#include "apt-pkg/cachefile.h"
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
    NSArray *sources;
    NSArray *packages;
    BOOL cacheOpened;
    NSMutableDictionary <NSNumber *, PLSource *> *packageSourceMap;
}
@end

@implementation PLDatabase

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
        pkgInitConfig(*_config);
        pkgInitSystem(*_config, _system);
        
        _config->Set("Dir::Log", "/var/mobile/Library/Caches/xyz.willy.Zebra/logs");
        _config->Set("Dir::State::Lists", "/var/mobile/Library/Caches/xyz.willy.Zebra/lists");
        _config->Set("Dir::Bin::dpkg", "/usr/libexec/zebra/supersling");
        _config->Set("Acquire::AllowInsecureRepositories", true);
        
        self->sourceList = new pkgSourceList();
        self->packageSourceMap = [NSMutableDictionary new];
    }
    
    return self;
}

- (BOOL)openCache {
    if (cacheOpened) return true;
    
    while (!_error->empty()) _error->Discard();
    
    BOOL result = cache.Open(NULL, false);
    if (!result) {
        while (!_error->empty()) {
            std::string error;
            bool warning = !_error->PopMessage(error);
            
            NSLog(@"[Plains] %@ while opening cache: %s", warning ? @"Warning" : @"Error", error.c_str());
        }
    }
    
    cacheOpened = result;
    return result;
}

- (void)closeCache {
    if (cacheOpened) {
        cache.Close();
        cacheOpened = false;
    }
}

- (void)refreshSources {
    [self readSourcesFromList:sourceList];
    
    pkgAcquire fetcher = pkgAcquire(NULL);
    if (fetcher.GetLock(_config->FindDir("Dir::State::Lists")) == false)
        return;

    // Populate it with the source selection
    if (self->sourceList->GetIndexes(&fetcher) == false)
        return;

    AcquireUpdate(fetcher, 0, true);
    
    while (!_error->empty()) { // Not sure AcquireUpdate() actually throws errors but i assume it does
        std::string error;
        bool warning = !_error->PopMessage(error);
        
        NSLog(@"[Plains] %@ while refreshing sources: %s", warning ? @"Warning" : @"Error", error.c_str());
    }
    
    [self fetchSourcePackages];
    [self fetchAllPackages];
}

- (void)readSourcesFromList:(pkgSourceList *)sourceList {
    self->sources = NULL;
    sourceList->ReadMainList();
    
    NSMutableArray *tempSources = [NSMutableArray new];
    for (pkgSourceList::const_iterator iterator = sourceList->begin(); iterator != sourceList->end(); iterator++) {
        metaIndex *index = *iterator;
        PLSource *source = [[PLSource alloc] initWithMetaIndex:index];
        [tempSources addObject:source];
    }
    self->sources = tempSources;
}

- (void)fetchSourcePackages {
    if (![self openCache]) return;
    
    for (PLSource *source in self.sources) {
        metaIndex *metaIndex = source.index;
        std::vector<pkgIndexFile *> *indexFiles = metaIndex->GetIndexFiles();
        for (std::vector<pkgIndexFile *>::const_iterator iterator = indexFiles->begin(); iterator != indexFiles->end(); iterator++) {
            debPackagesIndex *packagesIndex = (debPackagesIndex *)*iterator;
            if (packagesIndex != NULL) {
                pkgCache::PkgFileIterator package = (*packagesIndex).FindInCache(cache);
                if (!package.end()) {
                    packageSourceMap[@(package->ID)] = source;
                }
            }
        }
    }
}

- (void)fetchAllPackages {
    if (![self openCache]) return;
    
    self->packages = NULL;
    
    pkgDepCache *depCache = cache.GetDepCache();
    pkgRecords *records = new pkgRecords(*depCache);
    
    NSMutableArray *packages = [NSMutableArray arrayWithCapacity:depCache->Head().PackageCount];
    for (pkgCache::PkgIterator iterator = depCache->PkgBegin(); !iterator.end(); iterator++) {
        PLPackage *package = [[PLPackage alloc] initWithIterator:iterator depCache:depCache records:records];
        if (package) [packages addObject:package];
    }
    self->packages = packages;
}

- (NSArray <PLSource *> *)sources {
    if (!self->sources || self->sources.count == 0) {
        [self readSourcesFromList:self->sourceList];
    }
    return self->sources;
}

- (NSArray <PLPackage *> *)packages {
    if (!self->packages || self->packages.count == 0) {
        [self fetchAllPackages];
    }
    return [[self->packages filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.installed == TRUE AND SELF.role < 4"]] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
}

- (PLSource *)sourceFromID:(unsigned long)identifier {
    PLSource *source = packageSourceMap[@(identifier)];
    return source; // If a source isn't found return the local repository (later)
}

@end
