//
//  PLDatabase.m
//  Plains
//
//  Created by Wilson Styres on 2/27/21.
//

#import "PLDatabase.h"

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

@interface PLDatabase () {
    pkgCacheFile cache;
    pkgProblemResolver *resolver;
    PLDownloadStatus *status;
//    PLInstallStatus *installStatus;
    APT::Progress::PackageManager *installStatus;
    NSArray *sources;
    NSArray *packages;
    NSArray *updates;
    BOOL cacheOpened;
    BOOL refreshing;
}
@end

@implementation PLDatabase

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
    static PLDatabase *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [PLDatabase new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    
    if (self) {
        
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
//    self->status = new PLDownloadStatus(delegate);
//    pkgAcquire *fetcher = new pkgAcquire(self->status);
//    pkgRecords records = pkgRecords(self->cache);
//    pkgPackageManager *manager = _system->CreatePM(self->cache.GetDepCache());
//    manager->GetArchives(fetcher, self->sourceList, &records);
//    
//    // I don't really like this output redirection deal, I can do this better with
//    // PLInstallStatus but then I don't get any of the configuration text
//    // which people seem to like because it makes them feel like a hacker
//    
//    int *outPipe = (int *)malloc(sizeof(int) * 2);
//    int *errPipe = (int *)malloc(sizeof(int) * 2);
//    pipe(outPipe);
//    pipe(errPipe);
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
//    dispatch_source_t errSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, errPipe[0], 0, readQueue);
//    dispatch_source_set_event_handler(errSource, ^{
//        char *buffer = (char *)malloc(BUFSIZ * sizeof(char));
//        ssize_t bytes = read(errPipe[0], buffer, BUFSIZ);
//        
//        // Read from output and notify delegate
//        if (bytes > 0) {
//            NSString *string = [[NSString alloc] initWithBytes:buffer length:bytes encoding:NSUTF8StringEncoding];
//            if (string) {
//                NSArray <NSString *> *components = [string componentsSeparatedByString:@":"];
//                if (components.count == 4) {
//                    [delegate progressUpdate:components[2].floatValue];
//                    [delegate statusUpdate:components[3] atLevel:PLLogLevelError];
//                } else {
//                    [delegate statusUpdate:string atLevel:PLLogLevelError];
//                }
//            }
//        }
//        else {
//            dispatch_source_cancel(errSource);
//        }
//        
//        free(buffer);
//    });
//    dispatch_source_set_cancel_handler(errSource, ^{
//        close(errPipe[0]);
//        dispatch_semaphore_signal(lock);
//    });
//    
//    dispatch_activate(outSource);
//    dispatch_activate(errSource);
//    
//    self->installStatus = new APT::Progress::PackageManagerProgressFd(outPipe[1]);
//    
//    dup2(outPipe[1], STDOUT_FILENO);
//    dup2(errPipe[1], STDERR_FILENO);
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
//        close(errPipe[0]);
//        close(errPipe[1]);
//        
//        free(outPipe);
//        free(errPipe);
//    });
}

@end
