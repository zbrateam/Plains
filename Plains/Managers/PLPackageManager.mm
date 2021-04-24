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

#include "apt-pkg/pkgcache.h"
#include "apt-pkg/init.h"
#include "apt-pkg/pkgsystem.h"
#include "apt-pkg/update.h"
#include "apt-pkg/acquire.h"
#include "apt-pkg/acquire-item.h"
#include "apt-pkg/error.h"
#include "apt-pkg/install-progress.h"
#include "apt-pkg/metaindex.h"
#include "apt-pkg/debindexfile.h"

NSString *const PLDatabaseUpdateNotification = @"PlainsDatabaseUpdate";

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
        
        [this->delegate statusUpdate:message atLevel:PLLogLevelStatus];
    }
    
    virtual void Done(pkgAcquire::ItemDesc &item) {
        NSString *name = [NSString stringWithUTF8String:item.ShortDesc.c_str()];
        NSString *message = [NSString stringWithFormat:@"Finished Downloading %@.", name];
        
        [this->delegate statusUpdate:message atLevel:PLLogLevelStatus];
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
        pkgAcquireStatus::Start();
        
        [this->delegate startedDownloads];
    }
    
    virtual void Stop() {
        pkgAcquireStatus::Stop();
        
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
        PackageManager::Start();

        [this->delegate startedInstalls];
    }

    void Stop() override {
        PackageManager::Stop();

        [this->delegate progressUpdate:100.0];
        [this->delegate finishedInstalls];
    }

    pid_t fork() override {
        pid_t pid = ::fork();
        NSLog(@"Fork");
        return pid;
    }
    
    void StartDpkg() override {
        [this->delegate statusUpdate:@"Running Debian Packager." atLevel:PLLogLevelStatus];
    }

    void Pulse() override {
        [this->delegate progressUpdate:percentage];
    }

    bool StatusChanged(std::string PackageName, unsigned int StepsDone, unsigned int TotalSteps, std::string HumanReadableAction) override {
        NSString *message = [NSString stringWithUTF8String:HumanReadableAction.c_str()];

        [this->delegate statusUpdate:message atLevel:PLLogLevelStatus];

        return true;
    }

    void Error(std::string PackageName, unsigned int StepsDone, unsigned int TotalSteps, std::string ErrorMessage) override {
        NSString *message = [NSString stringWithUTF8String:ErrorMessage.c_str()];

        [this->delegate statusUpdate:message atLevel:PLLogLevelError];
    }

    void ConffilePrompt(std::string PackageName, unsigned int StepsDone, unsigned int TotalSteps, std::string ConfMessage) override {
        NSString *message = [NSString stringWithUTF8String:ConfMessage.c_str()];

        [this->delegate statusUpdate:message atLevel:PLLogLevelInfo];
    }
};

@interface PLPackageManager () {
    pkgCacheFile cache;
    pkgProblemResolver *resolver;
    PLDownloadStatus *status;
    PLInstallStatus *installStatus;
//    APT::Progress::PackageManager *installStatus;
    NSArray *sources;
    NSArray *packages;
    NSArray *updates;
    BOOL cacheOpened;
    BOOL refreshing;
}
@end

@implementation PLPackageManager

+ (void)load {
    [super load];
    
    pkgInitConfig(*_config);
    pkgInitSystem(*_config, _system);
    
    _config->Set("Acquire::AllowInsecureRepositories", true);
    
#if DEBUG
//    _config->Set("Debug::pkgProblemResolver", true);
//    _config->Set("Debug::pkgAcquire", true);
//    _config->Set("Debug::pkgAcquire::Worker", true);
#endif
    
#if TARGET_OS_MACCATALYST
    _config->Set("Dir::Log", "/Users/wstyres/Library/Caches/xyz.willy.Zebra/logs");
    _config->Set("Dir::State::Lists", "/Users/wstyres/Library/Caches/xyz.willy.Zebra/lists");
    _config->Set("Dir::Cache", "/Users/wstyres/Library/Caches/xyz.willy.Zebra/");
    _config->Set("Dir::State", "/Users/wstyres/Library/Caches/xyz.willy.Zebra/");
    _config->Set("Dir::Bin::dpkg", "/opt/procursus/libexec/zebra/supersling");
#else
    _config->Set("Dir::Log", "/var/mobile/Library/Caches/xyz.willy.Zebra/logs");
    _config->Set("Dir::State::Lists", "/var/mobile/Library/Caches/xyz.willy.Zebra/lists");
    _config->Set("Dir::Bin::dpkg", "/usr/libexec/zebra/supersling");
#endif
}

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
        NSLog(@"status fd: %d", _config->FindI("APT::Status-Fd"));
    }
    
    return self;
}

- (pkgCacheFile &)cache {
    [self openCache];
    return self->cache;
}

- (pkgProblemResolver *)resolver {
    [self openCache];
    return self->resolver;
}

- (BOOL)openCache {
    if (cacheOpened) return true;
    
    while (!_error->empty()) _error->Discard();
    
    BOOL result = cache.Open(NULL, false);
    if (!result) {
        while (!_error->empty()) {
            std::string error;
            bool warning = !_error->PopMessage(error);
            
            NSLog(@"[Plains] %@ while opening cache: %s", warning ? @"Warning" : @"Error", error.c_str());
        }
    } else {
        resolver = new pkgProblemResolver(self->cache);
    }
    
    cacheOpened = result;
    return result;
}

- (void)closeCache {
    if (cacheOpened) {
        cache.Close();
        cacheOpened = false;
    }
}

- (void)import {
    [self closeCache];
    if (![self openCache]) return;
    
    self->packages = NULL;
    
    pkgDepCache *depCache = cache.GetDepCache();
    pkgRecords *records = new pkgRecords(*depCache);
    
    NSMutableArray *packages = [NSMutableArray arrayWithCapacity:depCache->Head().PackageCount];
    NSMutableArray *updates = [NSMutableArray arrayWithCapacity:16];
    for (pkgCache::PkgIterator iterator = depCache->PkgBegin(); !iterator.end(); iterator++) {
        PLPackage *package = [[PLPackage alloc] initWithIterator:iterator depCache:depCache records:records];
        if (package) [packages addObject:package];
        if (package.hasUpdate) [updates addObject:package];
    }
    self->packages = packages;
    self->updates = updates;
    
    if (self->updates.count) [[NSNotificationCenter defaultCenter] postNotificationName:PLDatabaseUpdateNotification object:nil userInfo:@{@"count": @(self->updates.count)}];
}

- (void)importSourcesFromList:(pkgSourceList *)list {
    [self closeCache];
    if (![self openCache]) return;
    
    NSMutableArray *mutablePackages = [self->packages mutableCopy];
    std::vector<uint16_t> sourceIDs;
    sourceIDs.reserve(list->SrcList.capacity());
    
    for (pkgSourceList::const_iterator iterator = list->begin(); iterator != list->end(); iterator++) {
        metaIndex *index = *iterator;
        std::vector<pkgIndexFile *> *indexFiles = index->GetIndexFiles();
        for (std::vector<pkgIndexFile *>::const_iterator iterator = indexFiles->begin(); iterator != indexFiles->end(); iterator++) {
            debPackagesIndex *packagesIndex = (debPackagesIndex *)*iterator;
            if (packagesIndex != NULL) {
                pkgCache::PkgFileIterator package = (*packagesIndex).FindInCache(cache);
                if (!package.end()) {
                    sourceIDs.push_back(package->ID);
                }
            }
        }
    }
    
    pkgDepCache *depCache = cache.GetDepCache();
    pkgRecords *records = new pkgRecords(*depCache);
    for (pkgCache::PkgIterator iterator = depCache->PkgBegin(); !iterator.end(); iterator++) {
        pkgCache::VerIterator verIterator = depCache->GetPolicy().GetCandidateVer(iterator);
        if (verIterator) {
            unsigned long sourceID = verIterator.FileList().File()->ID;
            if (std::find(sourceIDs.begin(), sourceIDs.end(), sourceID) != sourceIDs.end()) {
                PLPackage *package = [[PLPackage alloc] initWithIterator:iterator depCache:depCache records:records];
                if (package) {
                    NSLog(@"Added: %@", package.name);
                    [mutablePackages addObject:package];
                }
            }
        }
    }
    
    self->packages = mutablePackages;
}

- (NSArray <PLPackage *> *)packages {
    if (!self->packages || self->packages.count == 0) {
        [self import];
    }
    return self->packages;
}

- (NSArray <PLPackage *> *)updates {
    return self->updates;
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

- (void)startDownloads:(id<PLConsoleDelegate>)delegate {
    self->status = new PLDownloadStatus(delegate);
    pkgAcquire *fetcher = new pkgAcquire(self->status);
    pkgRecords records = pkgRecords(self->cache);
    pkgPackageManager *manager = _system->CreatePM(self->cache.GetDepCache());
    manager->GetArchives(fetcher, [[PLSourceManager sharedInstance] sourceList], &records);

    // Subclassing APT::Progress::PackageManager doesn't provide the hacker information and output from the package
    // stdout could be redirected, but a lot of garbage gets in the way
    // APT::Progress::PackageManager fork() is supposed to be called before fork is called but it doesn't work properly
    self->installStatus = new PLInstallStatus(delegate);

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        fetcher->Run(); // can change the pulse interval here, i think the default is 500000

        manager->DoInstall(self->installStatus);

        [delegate finishedInstalls];
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

@end
