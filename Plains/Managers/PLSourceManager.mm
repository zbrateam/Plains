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

#include <spawn.h>
#include "apt-pkg/acquire.h"
#include "apt-pkg/acquire-item.h"
#include "apt-pkg/pkgcache.h"
#include "apt-pkg/debindexfile.h"
#include "apt-pkg/metaindex.h"
#include "apt-pkg/sourcelist.h"
#include "apt-pkg/update.h"

NSString *const PLStartedSourceRefreshNotification = @"StartedSourceRefresh";
NSString *const PLStartedSourceDownloadNotification = @"StartedSourceDownload";
NSString *const PLFailedSourceDownloadNotification = @"FailedSourceDownload";
NSString *const PLFinishedSourceDownloadNotification = @"FinishedSourceDownload";
NSString *const PLFinishedSourceRefreshNotification = @"FinishedSourceRefresh";
NSString *const PLSourceListUpdatedNotification = @"SourceListUpdated";

class PLSourceStatus: public pkgAcquireStatus {
public:
    
    NSString* UUIDForItem(pkgAcquire::ItemDesc &item) {
        NSString *shortDesc = [NSString stringWithUTF8String:item.Owner->ShortDesc().c_str()];
        NSMutableCharacterSet *allowed = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
        [allowed removeCharactersInString:@"_"];
        shortDesc = [shortDesc stringByAddingPercentEncodingWithAllowedCharacters:allowed];
        
        NSRange filenameRange = [shortDesc rangeOfString:@"/" options:NSBackwardsSearch];
        if (filenameRange.location != NSNotFound) shortDesc = [shortDesc substringToIndex:filenameRange.location + 1];
        
        NSURL *URL = [NSURL URLWithString:shortDesc];
        NSString *URLString = [URL absoluteString];
        NSString *schemeless = [URL scheme] ? [[URLString stringByReplacingOccurrencesOfString:[URL scheme] withString:@""] substringFromIndex:3] : URLString; //Removes scheme and ://
        return [schemeless stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    }
    
    virtual bool MediaChange(std::string Media, std::string Drive) {
        return false;
    }
    
    virtual void Fetch(pkgAcquire::ItemDesc &item) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PLStartedSourceDownloadNotification object:nil userInfo:@{@"uuid": UUIDForItem(item)}];
    }
    
    virtual void Done(pkgAcquire::ItemDesc &item) {
        [[NSNotificationCenter defaultCenter] postNotificationName:PLFinishedSourceDownloadNotification object:nil userInfo:@{@"uuid": UUIDForItem(item)}];
    }
    
    virtual void Fail(pkgAcquire::ItemDesc &item) {
        if (item.Owner->Status == pkgAcquire::Item::StatIdle || item.Owner->Status == pkgAcquire::Item::StatDone) return;
        if (item.Owner->ErrorText.empty()) return;
        
        NSString *reason = [NSString stringWithFormat:@"%s - %s", item.ShortDesc.c_str(), item.Owner->ErrorText.c_str()];
        [[NSNotificationCenter defaultCenter] postNotificationName:PLFailedSourceDownloadNotification object:nil userInfo:@{@"uuid": UUIDForItem(item), @"reason": reason}];
    }
    
    virtual bool Pulse(pkgAcquire *owner) {
        return true;
    }
    
    virtual void Start() {
        pkgAcquireStatus::Start();
        
        [[NSNotificationCenter defaultCenter] postNotificationName:PLStartedSourceRefreshNotification object:nil];
    }
    
    virtual void Stop() {
        pkgAcquireStatus::Stop();
        
        [[NSNotificationCenter defaultCenter] postNotificationName:PLFinishedSourceRefreshNotification object:nil];
    }
};

@interface PLSourceManager () {
    PLPackageManager *packageManager;
    PLSourceStatus *status;
    pkgSourceList *sourceList;
    NSArray <PLSource *> *sources;
    NSDictionary <NSNumber *, PLSource *> *sourcesMap;
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
        
        self->sourceList = [self->packageManager cache].GetSourceList();
        [self generateSourcesFile];
        [self readSources];
    }
    
    return self;
}

- (pkgSourceList *)sourceList {
    return self->sourceList;
}

- (void)readSources {
    self->sources = NULL;
    sourceList->ReadMainList();
    
    NSMutableArray *tempSources = [NSMutableArray new];
    NSMutableDictionary *tempMap = [NSMutableDictionary new];
    pkgCacheFile &cache = [packageManager cache];
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
    self->sourcesMap = tempMap;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PLSourceListUpdatedNotification object:NULL];
}

- (NSArray <PLSource *> *)sources {
    if (!self->sources || self->sources.count == 0) {
        [self readSources];
    }
    return self->sources;
}

- (void)refreshSources {
    if (refreshInProgress) return;
    
    refreshInProgress = YES;
    
    [self readSources];
    
    [[PLConfig sharedInstance] clearErrors];
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        self->status = new PLSourceStatus();
        pkgAcquire fetcher = pkgAcquire(self->status);
        if (fetcher.GetLock(_config->FindDir("Dir::State::Lists")) == false)
            return;

        // Populate it with the source selection
        if (self->sourceList->GetIndexes(&fetcher) == false)
            return;

        AcquireUpdate(fetcher, 0, true);

        [[PLConfig sharedInstance] errorMessages];
        
        [self->packageManager import];
        [self readSources];
        
        self->refreshInProgress = NO;
    });
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
    
    [self refreshSources];
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
    
    [self refreshSources];
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
    unsigned long sourceID = package.verIterator.FileList().File()->ID;
    return sourcesMap[@(sourceID)];
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
