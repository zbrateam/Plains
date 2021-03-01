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
        
        self->sourceList = new pkgSourceList();
        self->sourceList->ReadMainList();
    }
    
    return self;
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
