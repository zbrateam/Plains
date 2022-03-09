//
//  PLPackageManager.m
//  Plains
//
//  Created by Wilson Styres on 2/27/21.
//

#import "PLPackageManager.h"

#import "PLSource.h"
#import "PLPackage.h"
#import "PLConsoleDelegate.h"
#import "PLSourceManager.h"
#import "PLConfig.h"

PL_APT_PKG_IMPORTS_BEGIN
#include "apt-pkg/pkgsystem.h"
#include "apt-pkg/pkgcache.h"
#include "apt-pkg/update.h"
#include "apt-pkg/acquire.h"
#include "apt-pkg/acquire-item.h"
#include "apt-pkg/error.h"
#include "apt-pkg/install-progress.h"
#include "apt-pkg/metaindex.h"
#include "apt-pkg/debindexfile.h"
#include "apt-pkg/debfile.h"
#include "apt-pkg/fileutl.h"
#include "apt-pkg/statechanges.h"
#include "apt-pkg/tagfile.h"
PL_APT_PKG_IMPORTS_END

#include <fcntl.h>
#include <unistd.h>
#include <spawn.h>

extern char **environ;

NSNotificationName const PLDatabaseImportNotification = @"PLDatabaseImportNotification";
NSNotificationName const PLDatabaseRefreshNotification = @"PLDatabaseRefreshNotification";

NSString *const PLErrorDomain = @"PLErrorDomain";
NSInteger const PLPackageManagerErrorGeneral = 0;
NSInteger const PLPackageManagerErrorInvalidDebFile = 1;
NSInteger const PLPackageManagerErrorInvalidDebControl = 2;

class PLDownloadStatus: public pkgAcquireStatus {
private:
    id <PLConsoleDelegate> delegate;
public:
    PLDownloadStatus(id <PLConsoleDelegate> delegate) {
        this->delegate = delegate;
    }
    
    virtual bool MediaChange(std::string Media, std::string Drive) {
        return false;
    }
    
    virtual void Fetch(pkgAcquire::ItemDesc &item) {
        NSString *name = [NSString stringWithUTF8String:item.ShortDesc.c_str()];
        NSString *message = [NSString stringWithFormat:@"Downloading %@.", name];
        
        [this->delegate statusUpdate:message atLevel:PLLogLevelInfo];
    }
    
    virtual void Done(pkgAcquire::ItemDesc &item) {
        NSString *name = [NSString stringWithUTF8String:item.ShortDesc.c_str()];
        NSString *message = [NSString stringWithFormat:@"Finished Downloading %@.", name];
        
        [this->delegate statusUpdate:message atLevel:PLLogLevelInfo];
    }
    
    virtual void Fail(pkgAcquire::ItemDesc &item) {
        NSString *name = [NSString stringWithUTF8String:item.ShortDesc.c_str()];
        NSString *error = [NSString stringWithUTF8String:item.Owner->ErrorText.c_str()];
        NSString *message = [NSString stringWithFormat:@"Error while trying to download %@: %@.", name, error];
        
        [this->delegate statusUpdate:message atLevel:PLLogLevelError];
    }
    
    virtual bool Pulse(pkgAcquire *owner) {
        pkgAcquireStatus::Pulse(owner);
        CGFloat currentProgress = this->Percent;
        
        [this->delegate progressUpdate:currentProgress];
        
        return true;
    }
    
    virtual void Start() {
        [this->delegate startedDownloads];
    }
    
    virtual void Stop() {
        [this->delegate progressUpdate:100.0];
        [this->delegate finishedDownloads];
    }
};

class PLInstallStatus: public APT::Progress::PackageManager {
private:
    id <PLConsoleDelegate> delegate;
public:
    PLInstallStatus(id <PLConsoleDelegate> delegate) {
        this->delegate = delegate;
    }

    void Start(int child) override {
        [this->delegate startedInstalls];
    }

    void Stop() override {
        [this->delegate progressUpdate:100.0];
        [this->delegate finishedInstalls];
    }
    
    void StartDpkg() override {
        [this->delegate statusUpdate:@"Running Debian Packager." atLevel:PLLogLevelStatus];
    }

    void Pulse() override {
        [this->delegate progressUpdate:percentage];
    }

    bool StatusChanged(std::string PackageName, unsigned int StepsDone, unsigned int TotalSteps, std::string HumanReadableAction) override {
        NSString *message = [NSString stringWithUTF8String:HumanReadableAction.c_str()];

        [this->delegate statusUpdate:message atLevel:PLLogLevelInfo];
        [this->delegate progressUpdate:(CGFloat)StepsDone / (CGFloat)TotalSteps];

        return true;
    }

    void Error(std::string PackageName, unsigned int StepsDone, unsigned int TotalSteps, std::string ErrorMessage) override {
        NSString *message = [NSString stringWithUTF8String:ErrorMessage.c_str()];

        [this->delegate statusUpdate:message atLevel:PLLogLevelError];
        [this->delegate progressUpdate:(CGFloat)StepsDone / (CGFloat)TotalSteps];
    }

    void ConffilePrompt(std::string PackageName, unsigned int StepsDone, unsigned int TotalSteps, std::string ConfMessage) override {
        NSString *message = [NSString stringWithUTF8String:ConfMessage.c_str()];

        [this->delegate statusUpdate:message atLevel:PLLogLevelInfo];
        [this->delegate progressUpdate:(CGFloat)StepsDone / (CGFloat)TotalSteps];
    }
};

@interface PLPackageManager () {
    pkgCacheFile *cache;
    pkgProblemResolver *resolver;
    PLDownloadStatus *status;
    PLInstallStatus *installStatus;
//    APT::Progress::PackageManager *installStatus;
    NSArray *sources;
    NSArray *packages;
    NSArray *updates;
    BOOL cacheOpened;
    BOOL refreshing;
//    int finishFD;
}
@end

@implementation PLPackageManager

+ (instancetype)sharedInstance {
    static PLPackageManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [PLPackageManager new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        self->cache = new pkgCacheFile();
    }
    
    return self;
}

- (pkgCacheFile &)cache {
    [self openCache];
    return *self->cache;
}

- (pkgProblemResolver *)resolver {
    [self openCache];
    return self->resolver;
}

- (BOOL)openCache {
    if (cacheOpened) return true;
    
    if (!_error->empty()) _error->Discard();
    
    BOOL result = cache->Open(NULL, false);
    if (!result) {
        while (!_error->empty()) {
            std::string error;
            bool warning = !_error->PopMessage(error);
            
            NSLog(@"[Plains] %@ while opening cache: %s", warning ? @"Warning" : @"Error", error.c_str());
        }
    } else {
        resolver = new pkgProblemResolver(*self->cache);
    }
    
    cacheOpened = result;
    return result;
}

- (void)closeCache {
    if (cacheOpened) {
        cache->Close();
        cacheOpened = false;
    }
}

- (void)import {
    if (cacheOpened) {
        pkgCacheFile *temporaryCache = new pkgCacheFile();
        if (temporaryCache->Open(NULL, false)) {
            pkgDepCache *depCache = temporaryCache->GetDepCache();
            pkgRecords *records = new pkgRecords(*depCache);
            NSArray *import = [self packagesAndUpdatesFromDepCache:depCache records:records];

            self->packages = import[0];
            self->updates = import[1];

            cache->Close();
            self->cache = temporaryCache;
            resolver = new pkgProblemResolver(*self->cache);

            [[NSNotificationCenter defaultCenter] postNotificationName:PLDatabaseRefreshNotification object:nil userInfo:@{@"count": @(self->updates.count)}];
            return;
        }
    }
    
    [self closeCache];
    if (![self openCache]) return;
    
    pkgDepCache *depCache = cache->GetDepCache();
    pkgRecords *records = new pkgRecords(*depCache);
    NSArray *import = [self packagesAndUpdatesFromDepCache:depCache records:records];
    
    self->packages = import[0];
    self->updates = import[1];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:PLDatabaseImportNotification object:nil userInfo:@{@"count": @(self->updates.count)}];
}

- (NSArray <NSArray *> *)packagesAndUpdatesFromDepCache:(pkgDepCache *)depCache records:(pkgRecords *)records {
    NSMutableArray *packages = [NSMutableArray arrayWithCapacity:depCache->Head().PackageCount];
    NSMutableArray *updates = [NSMutableArray arrayWithCapacity:16];
    for (pkgCache::PkgIterator iterator = depCache->PkgBegin(); !iterator.end(); iterator++) {
        PLPackage *package = [[PLPackage alloc] initWithIterator:depCache->GetPolicy().GetCandidateVer(iterator) depCache:depCache records:records];
        if (package) [packages addObject:package];
        if (package.hasUpdate) [updates addObject:package];
    }
    return @[packages, updates];
}

- (NSArray <PLPackage *> *)packages {
    if (!self->packages || self->packages.count == 0) {
        [self import];
    }
    return self->packages;
}

- (NSArray <PLPackage *> *)updates {
    return [self->updates sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
}

- (void)fetchPackagesMatchingFilter:(BOOL (^)(PLPackage *package))filter completion:(void (^)(NSArray <PLPackage *> *packages))completion {
    NSMutableArray *filteredPackages = [NSMutableArray new];
    for (PLPackage *package in self.packages) {
        if (filter(package)) {
            [filteredPackages addObject:package];
        }
    }
    [filteredPackages sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES selector:@selector(caseInsensitiveCompare:)]]];
    completion(filteredPackages);
}

- (void)downloadAndPerform:(id<PLConsoleDelegate>)delegate {
    self->status = new PLDownloadStatus(delegate);
    pkgAcquire *fetcher = new pkgAcquire(self->status);
    pkgRecords records = pkgRecords(*self->cache);
    
    pkgPackageManager *manager = _system->CreatePM(self->cache->GetDepCache());
    manager->GetArchives(fetcher, cache->GetSourceList(), &records);

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        if (fetcher->TotalNeeded() > 0) {
            pkgAcquire::RunResult downloadResult = fetcher->Run(); // can change the pulse interval here, i think the default is 500000
            if (downloadResult != pkgAcquire::RunResult::Continue) {
                while (!_error->empty()) {
                    std::string error;
                    bool warning = !_error->PopMessage(error);
                    NSString *message = [NSString stringWithUTF8String:error.c_str()];
                    
                    [delegate statusUpdate:message atLevel:warning ? PLLogLevelWarning : PLLogLevelError];
                }
                [delegate finishedDownloads];
                [delegate finishedInstalls];
                return;
            }
        }
        
        // Subclassing APT::Progress::PackageManager doesn't provide the hacker information and output from the package
        // stdout could be redirected, but a lot of garbage gets in the way
        // APT::Progress::PackageManager fork() is supposed to be called before fork is called but it doesn't work properly
        
        // Dispatch types for reading from finish fd
        dispatch_semaphore_t lock;
        dispatch_source_t outSource;
        
        // Get pipe number from plains
        std::vector <std::string> finishFDs = _config->FindVector("Plains::FinishFD");
        if (finishFDs.size() == 2) {
            int readPipe = atoi(finishFDs[0].c_str());
            int writePipe = atoi(finishFDs[1].c_str());
            
            _config->Set("APT::Keep-Fds::", writePipe);
            setenv("CYDIA", [NSString stringWithFormat:@"%d 1", writePipe].UTF8String, 1);
            
            // Setup the dispatch queues for reading output and errors
            lock = dispatch_semaphore_create(0);
            dispatch_queue_t readQueue = dispatch_queue_create("xyz.willy.Zebra.david", DISPATCH_QUEUE_CONCURRENT);

            // Setup the dispatch handler for the output pipe
            outSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, readPipe, 0, readQueue);
            dispatch_source_set_event_handler(outSource, ^{
                char *buffer = (char *)malloc(BUFSIZ * sizeof(char));
                ssize_t bytes = read(readPipe, buffer, BUFSIZ);

                // Read from output and notify delegate
                if (bytes > 0) {
                    NSString *string = [[NSString alloc] initWithBytes:buffer length:bytes encoding:NSUTF8StringEncoding];
                    if (string) {
                        [delegate finishUpdate:string];
                    }
                }
                else {
                    dispatch_source_cancel(outSource);
                }

                free(buffer);
            });
            dispatch_source_set_cancel_handler(outSource, ^{
                _config->Clear("APT::Keep-Fds::", writePipe);
                unsetenv("CYDIA");
                dispatch_semaphore_signal(lock);
            });

            dispatch_activate(outSource);
        }
        
        self->installStatus = new PLInstallStatus(delegate);
        pkgPackageManager::OrderResult installResult = manager->DoInstall(self->installStatus);
        if (installResult != pkgPackageManager::OrderResult::Completed) {
            while (!_error->empty()) {
                std::string error;
                bool warning = !_error->PopMessage(error);
                NSString *message = [NSString stringWithUTF8String:error.c_str()];
                
                [delegate statusUpdate:message atLevel:warning ? PLLogLevelWarning : PLLogLevelError];
            }
            [delegate finishedInstalls];
        }
        
        if (outSource != NULL) {
            dispatch_source_cancel(outSource);
            dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
        }
        
        [self removeAllDebs];
        [self updateExtendedStates];
    });
    
//    self->status = new PLDownloadStatus(delegate);
//    pkgAcquire *fetcher = new pkgAcquire(self->status);
//    pkgRecords records = pkgRecords(self->cache);
//    pkgPackageManager *manager = _system->CreatePM(self->cache.GetDepCache());
//    manager->GetArchives(fetcher, [[PLSourceManager sharedInstance] sourceList], &records);
//
//    // I don't really like this output redirection deal, I can do this better with
//    // PLInstallStatus but then I don't get any of the configuration text
//    // which people seem to like because it makes them feel like a hacker
//
//    int *outPipe = (int *)malloc(sizeof(int) * 2);
//    pipe(outPipe);
//
//    _config->Set("APT::Status-Fd", outPipe[0]);
//    _config->Set("APT::Keep-Fds", outPipe[0]);
//
//    // Setup the dispatch queues for reading output and errors
//    dispatch_semaphore_t lock = dispatch_semaphore_create(0);
//    dispatch_queue_t readQueue = dispatch_queue_create("xyz.willy.Zebra.david", DISPATCH_QUEUE_CONCURRENT);
//
//    // Setup the dispatch handler for the output pipe
//    dispatch_source_t outSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, outPipe[0], 0, readQueue);
//    dispatch_source_set_event_handler(outSource, ^{
//        char *buffer = (char *)malloc(BUFSIZ * sizeof(char));
//        ssize_t bytes = read(outPipe[0], buffer, BUFSIZ);
//
//        // Read from output and notify delegate
//        if (bytes > 0) {
//            NSString *string = [[NSString alloc] initWithBytes:buffer length:bytes encoding:NSUTF8StringEncoding];
//            if (string) {
//                NSArray <NSString *> *components = [string componentsSeparatedByString:@":"];
//                if (components.count >= 4) {
//                    [delegate progressUpdate:components[2].floatValue];
//                    [delegate statusUpdate:components[3] atLevel:PLLogLevelStatus];
//                } else {
//                    [delegate statusUpdate:string atLevel:PLLogLevelInfo];
//                }
//
//            }
//        }
//        else {
//            dispatch_source_cancel(outSource);
//        }
//
//        free(buffer);
//    });
//    dispatch_source_set_cancel_handler(outSource, ^{
//        close(outPipe[0]);
//        dispatch_semaphore_signal(lock);
//    });
//
//    dispatch_activate(outSource);
//
//    self->installStatus = new APT::Progress::PackageManagerProgressFd(outPipe[1]);
//
//    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
//        fetcher->Run(); // can change the pulse interval here, i think the default is 500000
//
//        manager->DoInstall(self->installStatus);
//        dispatch_source_cancel(outSource);
//
//        dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
//
//        [delegate finishedInstalls];
//
//        close(outPipe[0]);
//        close(outPipe[1]);
//
//        free(outPipe);
//    });
}

- (void)removeAllDebs {
    PLConfig *config = [PLConfig sharedInstance];
    NSString *debPath = [[config stringForKey:@"Dir::Cache"] stringByAppendingPathComponent:@"archives"];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:debPath];
    NSString *file;

    while (file = [enumerator nextObject]) {
        if ([[enumerator fileAttributes][NSFileType] isEqual:NSFileTypeDirectory]) continue;
        
        NSError *error = nil;
        BOOL result = [[NSFileManager defaultManager] removeItemAtPath:[debPath stringByAppendingPathComponent:file] error:&error];

        if (!result && error) {
            NSLog(@"[Zebra] Error while removing %@: %@", file, error);
        }
    }
}

- (void)updateExtendedStates {
    PLConfig *config = [PLConfig sharedInstance];
    
#if TARGET_OS_MACCATALYST
    NSString *root = @"/opt/procursus/";
#else
    NSString *root = @"/";
#endif
    
    NSString *ours = [[config stringForKey:@"Dir::State"] stringByAppendingPathComponent:@"extended_states"];
    NSString *theirs = [root stringByAppendingPathComponent:@"/var/lib/apt/extended_states"];
    
    const char *const argv[] = {
        [[PLConfig sharedInstance] stringForKey:@"Plains::Slingshot"].UTF8String,
        "/bin/mv",
        "-f",
        ours.UTF8String,
        theirs.UTF8String,
        NULL
    };
    
    pid_t pid;
    posix_spawn(&pid, argv[0], NULL, NULL, (char * const *)argv, environ);
    waitpid(pid, NULL, 0);
    
    symlink(theirs.UTF8String, ours.UTF8String);
}

- (void)searchForPackagesWithNamePrefix:(NSString *)prefix completion:(void (^)(NSArray <PLPackage *> *packages))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *searchResults = [self.packages filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.name BEGINSWITH[cd] %@", prefix]];
        
        completion(searchResults);
    });
}

- (void)searchForPackagesWithName:(NSString *)name completion:(void (^)(NSArray <PLPackage *> *packages))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *searchResults = [self.packages filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.name CONTAINS[cd] %@", name]];
        
        completion(searchResults);
    });
}

- (void)searchForPackagesWithDescription:(NSString *)description completion:(void (^)(NSArray <PLPackage *> *packages))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *searchResults = [self.packages filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.shortDescription CONTAINS[cd] %@", description]];

        completion(searchResults);
    });
}

- (void)searchForPackagesWithAuthorName:(NSString *)authorName completion:(void (^)(NSArray <PLPackage *> *packages))completion {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray *searchResults = [self.packages filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self.authorName CONTAINS[cd] %@", authorName]];

        completion(searchResults);
    });
}

- (NSString *)candidateVersionForPackage:(PLPackage *)package {
    const char *candidateChars = self.cache->GetCandidateVersion(package.iterator).VerStr();
    if (candidateChars && candidateChars[0] != 0) {
        return [NSString stringWithUTF8String:candidateChars];
    }
    return NULL;
}

- (PLPackage *_Nullable)findPackage:(PLPackage *)package {
    NSString *name = package.identifier;
    
    pkgDepCache *depCache = cache->GetDepCache();
    pkgRecords *records = new pkgRecords(*depCache);
    pkgCache::PkgIterator newIterator = depCache->FindPkg(name.UTF8String, "any");
    pkgCache::VerIterator newVerIterator = depCache->GetPolicy().GetCandidateVer(newIterator);
    
    return [[PLPackage alloc] initWithIterator:newVerIterator depCache:depCache records:records];
}

- (PLPackage *_Nullable)addDebFile:(NSURL *)url error:(NSError **)error {
    FileFd deb;
    if (!deb.Open(url.path.UTF8String, FileFd::ReadOnly)) {
        NSLog(@"Could not open file at path %@", url.path);
        *error = [NSError errorWithDomain:PLErrorDomain code:PLPackageManagerErrorInvalidDebFile userInfo:nil];
        return NULL;
    }
    
    debDebFile debFile = debDebFile(deb);
    debDebFile::MemControlExtract control = debDebFile::MemControlExtract("control");
    if (!control.Read(debFile)) {
        NSLog(@"Could not read control file from deb at path %@", url.path);
        *error = [NSError errorWithDomain:PLErrorDomain code:PLPackageManagerErrorInvalidDebControl userInfo:nil];
        return NULL;
    }

    pkgTagSection tag;
    if (!tag.Scan(control.Control, control.Length + 1)) {
        NSLog(@"Could not scan control file from deb at path %@", url.path);
        *error = [NSError errorWithDomain:PLErrorDomain code:PLPackageManagerErrorInvalidDebControl userInfo:nil];
        return NULL;
    }

    std::string packageIdentifier = tag.FindS("Package");
    std::string architecture = tag.FindS("Architecture");
    if (packageIdentifier.empty()) {
        NSLog(@"Could not retrieve package identifier from deb at path %@", url.path);
        *error = [NSError errorWithDomain:PLErrorDomain code:PLPackageManagerErrorInvalidDebControl userInfo:nil];
        return NULL;
    }
    if (architecture.empty()) {
        NSLog(@"Could not retrieve architecture from deb at path %@", url.path);
        *error = [NSError errorWithDomain:PLErrorDomain code:PLPackageManagerErrorInvalidDebControl userInfo:nil];
        return NULL;
    }

    pkgCacheFile *temporaryCache = new pkgCacheFile();
    pkgSourceList *sourceList = temporaryCache->GetSourceList();
    sourceList->AddVolatileFile(url.path.UTF8String);
    if (!temporaryCache->Open(NULL, false)) {
        NSLog(@"Could not open temporary cache");
        *error = [NSError errorWithDomain:PLErrorDomain code:PLPackageManagerErrorGeneral userInfo:nil];
        return NULL;
    }

    pkgDepCache *depCache = temporaryCache->GetDepCache();
    pkgRecords *records = new pkgRecords(*depCache);
    NSArray *import = [self packagesAndUpdatesFromDepCache:depCache records:records];

    self->packages = import[0];
    self->updates = import[1];

    cache->Close();
    self->cache = temporaryCache;
    resolver = new pkgProblemResolver(*self->cache);

    pkgCache::PkgIterator itr = cache->GetDepCache()->FindPkg(packageIdentifier, architecture);

    [[NSNotificationCenter defaultCenter] postNotificationName:PLDatabaseRefreshNotification object:nil userInfo:@{@"count": @(self->updates.count)}];
    return [[PLPackage alloc] initWithIterator:depCache->GetCandidateVersion(itr) depCache:depCache records:records];
}

- (void)setPackage:(PLPackage *)package held:(BOOL)held {
    NSMutableArray *mutableUpdates = [updates mutableCopy];
    
    APT::StateChanges states;
    if (held) { // Hold package
        states.Hold(package.verIterator);
        
        [mutableUpdates removeObject:package];
    } else if (!held) { // Release package
        states.Unhold(package.verIterator);
        
        if ([package hasUpdate]) [mutableUpdates addObject:package];
    }
    states.Save();
    
    self->updates = mutableUpdates;
    [[NSNotificationCenter defaultCenter] postNotificationName:PLDatabaseRefreshNotification object:nil userInfo:@{@"count": @(self->updates.count)}];
}

@end
