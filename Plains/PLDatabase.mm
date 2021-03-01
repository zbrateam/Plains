//
//  PLDatabase.m
//  Plains
//
//  Created by Wilson Styres on 2/27/21.
//

#import "PLDatabase.h"

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

- (NSArray *)sources {
    NSMutableArray *sourceURIs = [NSMutableArray new];
    
    for (pkgSourceList::const_iterator source = sourceList->begin(); source != sourceList->end(); ++source) {
        metaIndex *index = *source;
        std::string uriStdStr = index->GetURI();
        const char *uri = uriStdStr.c_str();
        if (uri) {
            NSString *uriString = [NSString stringWithUTF8String:uri];
            if (uriString) [sourceURIs addObject:uriString];
        }
    }
    
    return sourceURIs;
}

@end
