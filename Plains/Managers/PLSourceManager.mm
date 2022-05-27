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
#import "PLDownloadDelegate.h"
#import "PLErrorManager.h"

#include <spawn.h>

PL_APT_PKG_IMPORTS_BEGIN
#include "apt-pkg/acquire.h"
#include "apt-pkg/acquire-item.h"
#include "apt-pkg/pkgcache.h"
#include "apt-pkg/debindexfile.h"
#include "apt-pkg/metaindex.h"
#include "apt-pkg/sourcelist.h"
#include "apt-pkg/update.h"
#include "apt-pkg/pkgsystem.h"
#include "apt-pkg/fileutl.h"
#include "apt-pkg/strutl.h"
PL_APT_PKG_IMPORTS_END

extern char **environ;

NSNotificationName const PLStartedSourceRefreshNotification = @"PLStartedSourceRefreshNotification";
NSNotificationName const PLStartedSourceDownloadNotification = @"PLStartedSourceDownloadNotification";
NSNotificationName const PLFailedSourceDownloadNotification = @"PLFailedSourceDownloadNotification";
NSNotificationName const PLFinishedSourceDownloadNotification = @"PLFinishedSourceDownloadNotification";
NSNotificationName const PLFinishedSourceRefreshNotification = @"PLFinishedSourceRefreshNotification";
NSNotificationName const PLSourceListUpdatedNotification = @"PLSourceListUpdatedNotification";
NSNotificationName const PLSourceListPulseNotification = @"PLSourceListPulseNotification";

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
        [self generateSourcesFile];
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
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PLSourceListUpdatedNotification object:NULL];
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

- (void)generateSourcesFile {
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    PLConfig *config = [PLConfig sharedInstance];
    
    NSString *sourcesFilePath = [config stringForKey:@"Plains::SourcesList"];
    if (![defaultManager fileExistsAtPath:sourcesFilePath]) {
        [defaultManager createFileAtPath:sourcesFilePath contents:nil attributes:nil];
        
        NSString *zebraSource = @"Types: deb\nURIs: https://getzbra.com/repo/\nSuites: ./\nComponents:\n\n";
        [zebraSource writeToFile:sourcesFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    
    NSString *etcDir = [config stringForKey:@"Dir::Etc"];
    NSString *sourcePartsDir = [config stringForKey:@"Dir::Etc::sourceparts"];
    NSString *filename = sourcesFilePath.lastPathComponent;
    NSString *sourcesLinkPath = [NSString stringWithFormat:@"/%@/%@/%@", etcDir, sourcePartsDir, filename];
    if (![defaultManager fileExistsAtPath:sourcesLinkPath]) {
        const char *const argv[] = {
            [config stringForKey:@"Plains::Slingshot"].UTF8String,
            "/bin/ln",
            "-s",
            sourcesFilePath.UTF8String,
            sourcesLinkPath.UTF8String,
            NULL
        };
        
        pid_t pid;
        posix_spawn(&pid, argv[0], NULL, NULL, (char * const *)argv, environ);
        waitpid(pid, NULL, 0);
    }
}

- (void)addSourceWithArchiveType:(NSString *)archiveType repositoryURI:(NSString *)URI distribution:(NSString *)distribution components:(NSArray <NSString *> *_Nullable)components {
    [self generateSourcesFile];
    
    NSString *repoEntry = [NSString stringWithFormat:@"Types: %@\nURIs: %@\nSuites: %@\nComponents: %@\n\n", archiveType, URI, distribution, components ? [components componentsJoinedByString:@" "] : @""];
    
    NSString *sourcesFilePath = [[PLConfig sharedInstance] stringForKey:@"Plains::SourcesList"];
    NSFileHandle *writeHandle = [NSFileHandle fileHandleForWritingAtPath:sourcesFilePath];
    [writeHandle seekToEndOfFile];
    [writeHandle writeData:[repoEntry dataUsingEncoding:NSUTF8StringEncoding]];
    [writeHandle closeFile];

    [self readSources];
    [self->packageManager import];
}

- (void)addSources:(NSArray <NSDictionary *> *)sources {
    [self generateSourcesFile];
    
    NSString *sourcesFilePath = [[PLConfig sharedInstance] stringForKey:@"Plains::SourcesList"];
    NSFileHandle *writeHandle = [NSFileHandle fileHandleForWritingAtPath:sourcesFilePath];
    [writeHandle seekToEndOfFile];
    for (NSDictionary *source in sources) {
        NSArray *components = source[@"Components"];
        NSString *repoEntry = [NSString stringWithFormat:@"Types: %@\nURIs: %@\nSuites: %@\nComponents: %@\n\n", source[@"Types"], source[@"URI"], source[@"Suites"], components ? [components componentsJoinedByString:@" "] : @""];
        [writeHandle writeData:[repoEntry dataUsingEncoding:NSUTF8StringEncoding]];
    }
    [writeHandle closeFile];

    [self readSources];
    [self->packageManager import];
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

- (PLSource *)sourceForUUID:(NSString *)UUID {
    for (PLSource *source in sources) {
        if ([source.UUID isEqualToString:UUID]) {
            return source;
        }
    }
    return NULL;
}

@end
