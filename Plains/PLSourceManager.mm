//
//  PLSourceManager.m
//  Plains
//
//  Created by Wilson Styres on 4/15/21.
//

#import "PLSourceManager.h"

#import "PLDatabase.h"
#import "PLSource.h"
#import "PLPackage.h"

#include <spawn.h>
#include "apt-pkg/acquire.h"
#include "apt-pkg/acquire-item.h"
#include "apt-pkg/pkgcache.h"
#include "apt-pkg/debindexfile.h"
#include "apt-pkg/metaindex.h"
#include "apt-pkg/sourcelist.h"
#include "apt-pkg/update.h"

NSString *const ZBStartedSourceRefreshNotification = @"StartedSourceRefresh";
NSString *const ZBStartedSourceDownloadNotification = @"StartedSourceDownload";
NSString *const ZBFinishedSourceDownloadNotification = @"FinishedSourceDownload";
NSString *const ZBStartedSourceImportNotification = @"StartedSourceImport";
NSString *const ZBFinishedSourceImportNotification = @"FinishedSourceImport";
NSString *const ZBUpdatesAvailableNotification = @"UpdatesAvailable";
NSString *const ZBFinishedSourceRefreshNotification = @"FinishedSourceRefresh";
NSString *const ZBAddedSourcesNotification = @"AddedSources";
NSString *const ZBRemovedSourcesNotification = @"RemovedSources";
NSString *const ZBSourceDownloadProgressUpdateNotification = @"SourceDownloadProgressUpdate";

@interface PLSourceManager () {
    PLDatabase *database;
    pkgSourceList *sourceList;
    NSArray <PLSource *> *sources;
    NSDictionary <NSNumber *, PLSource *> *sourcesMap;
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
        self->database = [PLDatabase sharedInstance];
        
        self->sourceList = new pkgSourceList();
        [self generateSourcesFile];
        [self readSourcesFromList:self->sourceList];
    }
    
    return self;
}

- (void)readSourcesFromList:(pkgSourceList *)sourceList {
    self->sources = NULL;
    sourceList->ReadMainList();
    
    NSMutableArray *tempSources = [NSMutableArray new];
    NSMutableDictionary *tempMap = [NSMutableDictionary new];
    pkgCacheFile &cache = [database cache];
    for (pkgSourceList::const_iterator iterator = sourceList->begin(); iterator != sourceList->end(); iterator++) {
        metaIndex *index = *iterator;
        PLSource *source = [[PLSource alloc] initWithMetaIndex:index];
        
        std::vector<pkgIndexFile *> *indexFiles = index->GetIndexFiles();
        for (std::vector<pkgIndexFile *>::const_iterator iterator = indexFiles->begin(); iterator != indexFiles->end(); iterator++) {
            debPackagesIndex *packagesIndex = (debPackagesIndex *)*iterator;
            if (packagesIndex != NULL) {
                pkgCache::PkgFileIterator package = (*packagesIndex).FindInCache(cache);
                if (!package.end()) {
                    tempMap[@(package->ID)] = source;
                }
            }
        }
        
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

        while (!_error->empty()) { // Not sure AcquireUpdate() actually throws errors but i assume it does
            std::string error;
            bool warning = !_error->PopMessage(error);

            printf("%s\n", error.c_str());
        }
        
        [database import];
    });
}


- (void)generateSourcesFile {
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    
    NSString *sourcesFilePath = [self sourcesFilePath];
    if (![defaultManager fileExistsAtPath:sourcesFilePath]) {
        [defaultManager createFileAtPath:sourcesFilePath contents:nil attributes:nil];
        
        NSString *zebraSource = @"Types: deb\nURIs: https://getzbra.com/repo/\nSuites: ./\nComponents:\n\n";
        [zebraSource writeToFile:sourcesFilePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    
    std::string sourcesLink = _config->Find("Dir::Etc") + "/" + _config->Find("Dir::Etc::sourceparts") + "/zebra.sources";
    NSString *sourcesLinkPath = [NSString stringWithUTF8String:sourcesLink.c_str()];
    if (![defaultManager fileExistsAtPath:sourcesLinkPath]) {
        pid_t pid;
        const char *const argv[] = {
            "/opt/procursus/libexec/zebra/supersling",
            "/bin/ln",
            "-s",
            "/Users/wstyres/Library/Caches/xyz.willy.Zebra/zebra.sources",
            "/opt/procursus/etc/apt/sources.list.d/zebra.sources",
            NULL
        };
        
        posix_spawn(&pid, argv[0], NULL, NULL, (char * const *)argv, environ);
        waitpid(pid, NULL, 0);
    }
}

- (NSString *)sourcesFilePath {
    std::string sources = _config->Find("Dir::Cache") + "zebra.sources";
    return [NSString stringWithUTF8String:sources.c_str()];
}

- (void)addSourceWithArchiveType:(NSString *)archiveType repositoryURI:(NSString *)URI distribution:(NSString *)distribution components:(NSArray <NSString *> *_Nullable)components {
    [self generateSourcesFile];
    
    NSString *repoEntry = [NSString stringWithFormat:@"Types: %@\nURIs: %@\nSuites: %@\nComponents: %@\n\n", archiveType, URI, distribution, components ? [components componentsJoinedByString:@" "] : @""];
    
    NSString *sourcesFilePath = [self sourcesFilePath];
    NSFileHandle *writeHandle = [NSFileHandle fileHandleForWritingAtPath:sourcesFilePath];
    [writeHandle seekToEndOfFile];
    [writeHandle writeData:[repoEntry dataUsingEncoding:NSUTF8StringEncoding]];
    [writeHandle closeFile];
}

- (void)removeSource:(PLSource *)sourceToRemove {
    NSString *sourcesFilePath = [self sourcesFilePath];
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
}

- (PLSource *)sourceForPackage:(PLPackage *)package {
    unsigned long sourceID = package.verIterator.FileList().File()->ID;
    return sourcesMap[@(sourceID)];
}

@end
