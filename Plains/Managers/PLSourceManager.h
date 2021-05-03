//
//  PLSourceManager.h
//  Plains
//
//  Created by Wilson Styres on 4/15/21.
//

#import <Foundation/Foundation.h>

#include "apt-pkg/sourcelist.h"

@class PLSource;
@class PLPackage;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const PLStartedSourceRefreshNotification;
extern NSString *const PLStartedSourceDownloadNotification;
extern NSString *const PLFinishedSourceDownloadNotification;
extern NSString *const PLFailedSourceDownloadNotification;
extern NSString *const PLFinishedSourceRefreshNotification;
extern NSString *const PLSourceListUpdatedNotification;

@interface PLSourceManager : NSObject
+ (instancetype)sharedInstance;
- (void)refreshSources;
- (pkgSourceList *)sourceList;
- (NSArray <PLSource *> *)sources;
- (void)addSourceWithArchiveType:(NSString *)archiveType repositoryURI:(NSString *)URI distribution:(NSString *)distribution components:(NSArray <NSString *> *_Nullable)components;
- (void)removeSource:(PLSource *)sourceToRemove;
- (PLSource *)sourceForPackage:(PLPackage *)package;
- (PLSource *)sourceForUUID:(NSString *)UUID;
@end

NS_ASSUME_NONNULL_END
