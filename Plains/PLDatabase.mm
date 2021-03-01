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

@interface PLDatabase () {
    pkgSourceList *sourceList;
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
//    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        self->sourceList->ReadMainList();

        pkgAcquire fetcher = pkgAcquire(NULL);
        if (fetcher.GetLock(_config->FindDir("Dir::State::Lists")) == false)
            return;

        // Populate it with the source selection
        if (self->sourceList->GetIndexes(&fetcher) == false)
            return;

        AcquireUpdate(fetcher, 0, true);
//    });
}

- (NSArray <PLSource *> *)sources {
    NSMutableArray *sources = [NSMutableArray new];
    
    for (pkgSourceList::const_iterator sourceIterator = sourceList->begin(); sourceIterator != sourceList->end(); ++sourceIterator) {
        metaIndex *index = *sourceIterator;
        PLSource *source = [[PLSource alloc] initWithMetaIndex:index];
        [sources addObject:source];
    }
    
    return sources;
}

@end
