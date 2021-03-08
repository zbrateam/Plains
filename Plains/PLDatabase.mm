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
}
@end

@implementation PLDatabase

- (id)init {
    self = [super init];
    
    if (self) {
        pkgInitConfig(*_config);
        pkgInitSystem(*_config, _system);
        
        _config->Set("Dir::State::Lists", "/var/mobile/Library/Caches/xyz.willy.Zebra/lists");
        
        self->sourceList = new pkgSourceList();
        self->sourceList->ReadMainList();
    }
    
    return self;
}

- (void)updateDatabase {
    // This code is for refreshing sources, not quite sure if I want it in the database yet.
//    pkgAcquire fetcher = pkgAcquire(NULL);
//    if (fetcher.GetLock(_config->FindDir("Dir::State::Lists")) == false)
//        return;
//
//    // Populate it with the source selection
//    if (self->sourceList->GetIndexes(&fetcher) == false)
//        return;
//
//    AcquireUpdate(fetcher, 0, true);
    
    self->sources = NULL;
    self->sourceList->ReadMainList();
    
    [self readSourcesFromList:self->sourceList];

    cache.Close();
    
    while (!_error->empty()) {
        NSLog(@"[Plains] Error is not empty, discarding");
        _error->Discard();
    }
    
    if (!cache.Open(NULL, false)) {
        while (!_error->empty()) {
            std::string error;
            bool warning = !_error->PopMessage(error);
            
            NSLog(@"[Plains] %@ while opening cache: %s", warning ? @"Warning" : @"Error", error.c_str());
        }
    }
    
    NSLog(@"[Plains] Cache Opened");
    pkgDepCache *depCache = cache.GetDepCache();
    pkgRecords *records = new pkgRecords(*depCache);
    NSLog(@"[Plains] Expected Package Count: %d", depCache->Head().PackageCount);
    
    NSMutableArray *packages = [NSMutableArray arrayWithCapacity:depCache->Head().PackageCount];
    for (pkgCache::PkgIterator iterator = depCache->PkgBegin(); !iterator.end(); iterator++) {
        PLPackage *package = [[PLPackage alloc] initWithIterator:iterator depCache:depCache records:records];
        if (package) [packages addObject:package];
    }
    self->packages = packages;
    NSLog(@"[Plains] Actual Package Count: %lu", (unsigned long)packages.count);
    
    int installedCount = 0;
    for (PLPackage *package in self->packages) {
        if (package.installed) {
            NSLog(@"[Plains] Installed Package: %@ v%@", [package name], [package installedVersion]);
        }
    }
    NSLog(@"[Plains] Installed Count: %d", installedCount);
}

- (void)readSourcesFromList:(pkgSourceList *)sourceList {
    NSMutableArray *tempSources = [NSMutableArray new];
    for (pkgSourceList::const_iterator iterator = sourceList->begin(); iterator != sourceList->end(); iterator++) {
        metaIndex *index = *iterator;
        PLSource *source = [[PLSource alloc] initWithMetaIndex:index];
        [tempSources addObject:source];
    }
    self->sources = tempSources;
}

- (NSArray <PLSource *> *)sources {
    if (!self->sources || self->sources.count == 0) {
        [self readSourcesFromList:self->sourceList];
    }
    return self->sources;
}

@end
