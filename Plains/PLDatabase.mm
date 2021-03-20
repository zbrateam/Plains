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
        
        self->sourceList = new pkgSourceList();
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
    
    [self readSourcesFromList:self->sourceList];

    cache.Close();
    
    if (!cache.Open(NULL, false)) {
        while (!_error->empty()) {
            std::string error;
            bool warning = !_error->PopMessage(error);
            
            NSLog(@"[Plains] %@ while opening cache: %s", warning ? @"Warning" : @"Error", error.c_str());
        }
    }
    
    pkgDepCache *depCache = cache.GetDepCache();
    pkgRecords *records = new pkgRecords(*depCache);
    
    NSMutableArray *packages = [NSMutableArray arrayWithCapacity:depCache->Head().PackageCount];
    for (pkgCache::PkgIterator iterator = depCache->PkgBegin(); !iterator.end(); iterator++) {
        PLPackage *package = [[PLPackage alloc] initWithIterator:iterator depCache:depCache records:records];
        if (package) [packages addObject:package];
    }
    self->packages = packages;
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

- (NSArray <PLSource *> *)sources {
    if (!self->sources || self->sources.count == 0) {
        [self readSourcesFromList:self->sourceList];
    }
    return self->sources;
}

- (NSArray <PLPackage *> *)packages {
    if (!self->packages || self->packages.count == 0) {
        [self updateDatabase];
    }
    return [[self->packages filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.installed == TRUE"]] sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
}

@end
