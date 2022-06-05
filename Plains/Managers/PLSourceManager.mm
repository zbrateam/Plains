//
//  PLSourceManager.m
//  Plains
//
//  Created by Wilson Styres on 4/15/21.
//

#import "PLSourceManager.h"

#import "PLPackageManager.h"
#import "PLSource.h"
#import "PLPackage.h"
#import "PLConfig.h"
#import "PLErrorManager.h"
#import <Plains/Plains-Swift.h>
#include <spawn.h>

PL_APT_PKG_IMPORTS_BEGIN
#import <apt-pkg/acquire.h>
#import <apt-pkg/acquire-item.h>
#import <apt-pkg/pkgcache.h>
#import <apt-pkg/debindexfile.h>
#import <apt-pkg/metaindex.h>
#import <apt-pkg/sourcelist.h>
#import <apt-pkg/update.h>
#import <apt-pkg/pkgsystem.h>
#import <apt-pkg/fileutl.h>
#import <apt-pkg/strutl.h>
PL_APT_PKG_IMPORTS_END

extern char **environ;

@interface PLSourceManager () {
    PLPackageManager *packageManager;
    pkgSourceList *sourceList;
    NSArray <PLSource *> *sources;
    NSMutableDictionary <NSNumber *, PLSource *> *sourcesMap;
    NSMutableArray *busyList;
    BOOL refreshInProgress;
}
@end

@implementation PLSourceManager

+ (instancetype)sharedInstance {
    static PLSourceManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [PLSourceManager new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self->packageManager = [PLPackageManager sharedInstance];

        pkgCacheFile *cache = new pkgCacheFile();
        self->sourceList = cache->GetSourceList();
        [self generateSourcesFileAndReturnError:nil];
        [self readSources];
    }
    
    return self;
}

- (void)dealloc {
    delete self->sourceList;
}

- (pkgSourceList *)sourceList {
    if (!self->sourceList) {
        pkgCacheFile *cache = new pkgCacheFile();
        self->sourceList = cache->GetSourceList();
    }
    
    return self->sourceList;
}

- (void)readSources {
    self->sources = NULL;
    if (!self->sourceList->ReadMainList())
        return;

    NSMutableArray *tempSources = [NSMutableArray new];
    for (pkgSourceList::const_iterator iterator = sourceList->begin(); iterator != sourceList->end(); iterator++) {
        metaIndex *index = *iterator;
        PLSource *source = [[PLSource alloc] initWithMetaIndex:index];
        
        [tempSources addObject:source];
    }
    
    self->sources = tempSources;
    self->sourcesMap = [NSMutableDictionary new];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PLSourceManager.sourceListDidUpdateNotification object:NULL];
}

- (NSArray <PLSource *> *)sources {
    if (!self->sources || self->sources.count == 0) {
        [self readSources];
    }
    return self->sources;
}

- (BOOL)rebuildCache {
    pkgCacheFile *cache = new pkgCacheFile();
    cache->RemoveCaches();

    if (!cache->BuildCaches()) {
        return NO;
    }

    self->sourceList = cache->GetSourceList();
    [self->packageManager import];
    [self readSources];
    return YES;
}

- (void)removeSource:(PLSource *)sourceToRemove {
    NSString *sourcesFilePath = [[PLConfig sharedInstance] stringForKey:@"Plains::SourcesList"];
    NSFileHandle *writeHandle = [NSFileHandle fileHandleForWritingAtPath:sourcesFilePath];
    NSMutableData *dataToWrite = [NSMutableData new];
    for (PLSource *source in self.sources) {
        if (![source.entryFilePath isEqualToString:sourceToRemove.entryFilePath]) continue;
        if (source == sourceToRemove) continue;
        
        NSString *entry = [NSString stringWithFormat:@"Types: %@\nURIs: %@\nSuites: %@\nComponents: %@\n\n", source.type, source.URI, source.distribution, @""];
        NSData *data = [entry dataUsingEncoding:NSUTF8StringEncoding];
        [dataToWrite appendData:data];
    }
    [writeHandle writeData:dataToWrite];
    [writeHandle truncateFileAtOffset:dataToWrite.length];
    [writeHandle closeFile];
    
    [self readSources];
    [self->packageManager import];
}

- (PLSource *)sourceForPackage:(PLPackage *)package {
    pkgCache::VerFileIterator fileList = package.verIterator.FileList();
    if (fileList.end()) return NULL;
    pkgCache::PkgFileIterator fileItr = fileList.File();
    if (fileItr.end()) return NULL;
    
    PLSource *sourceFromMap = sourcesMap[@(fileItr->ID)];
    if (sourceFromMap) return sourceFromMap;
    
    pkgIndexFile *index;
    if (!sourceList->FindIndex(fileItr, index)) return NULL;

    pkgDebianIndexTargetFile *targetFile = (pkgDebianIndexTargetFile *)index;
    std::string baseURI = targetFile->Target.Option(IndexTarget::BASE_URI);
    if (baseURI.empty()) return NULL;

    NSString *UUID = [NSString stringWithUTF8String:URItoFileName(baseURI).c_str()];
    PLSource *source = [self sourceForUUID:UUID];
    if (source) {
        sourcesMap[@(fileItr->ID)] = source;
    }
    return source;
}

@end
