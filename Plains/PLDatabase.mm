//
//  PLDatabase.m
//  Plains
//
//  Created by Wilson Styres on 2/27/21.
//

#import "PLDatabase.h"

#import "PLSource.h"

#include "apt-pkg/cachefile.h"
#include "apt-pkg/pkgcache.h"
#include "apt-pkg/init.h"
#include "apt-pkg/pkgsystem.h"
#include "apt-pkg/sourcelist.h"
#include "apt-pkg/metaindex.h"
#include "apt-pkg/update.h"
#include "apt-pkg/acquire.h"
#include "apt-pkg/debindexfile.h"

@interface PLDatabase () {
    pkgSourceList *sourceList;
    pkgCacheFile *cache;
    NSArray *sources;
}
@end

@implementation PLDatabase

- (id)init {
    self = [super init];
    
    if (self) {
        pkgInitConfig(*_config);
        pkgInitSystem(*_config, _system);
        
        _config->Set("Dir::State::Lists", "/var/mobile/Library/Application Support/xyz.willy.Zebra/lists");
        
        self->sourceList = new pkgSourceList();
        self->sourceList->ReadMainList();
    }
    
    return self;
}

- (void)updateDatabase {
    self->sources = NULL;
    self->sourceList->ReadMainList();
    
    pkgAcquire fetcher = pkgAcquire(NULL);
    if (fetcher.GetLock(_config->FindDir("Dir::State::Lists")) == false)
        return;
    
    // Populate it with the source selection
    if (self->sourceList->GetIndexes(&fetcher) == false)
        return;
    
    AcquireUpdate(fetcher, 0, true);
}

- (NSArray <PLSource *> *)sources {
    if (!self->sources || self->sources.count == 0) {
        NSMutableArray *tempSources = [NSMutableArray new];
        for (pkgSourceList::const_iterator iterator = sourceList->begin(); iterator != sourceList->end(); iterator++) {
            metaIndex *index = *iterator;
            PLSource *source = [[PLSource alloc] initWithMetaIndex:index];
            [tempSources addObject:source];
        }
        self->sources = tempSources;
    }
    return self->sources;
}

@end
