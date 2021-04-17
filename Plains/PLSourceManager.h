//
//  PLSourceManager.h
//  Plains
//
//  Created by Wilson Styres on 4/15/21.
//

#import <Foundation/Foundation.h>

@class PLSource;
@class PLPackage;

NS_ASSUME_NONNULL_BEGIN

//extern NSString *const PLStartedSourceRefreshNotification;
//extern NSString *const PLStartedSourceDownloadNotification;
//extern NSString *const PLFinishedSourceDownloadNotification;
//extern NSString *const PLStartedSourceImportNotification;
//extern NSString *const PLFinishedSourceImportNotification;
//extern NSString *const PLUpdatesAvailableNotification;
//extern NSString *const PLFinishedSourceRefreshNotification;
extern NSString *const PLAddedSourcesNotification;
extern NSString *const PLRemovedSourcesNotification;
//extern NSString *const PLSourceDownloadProgressUpdateNotification;

@interface PLSourceManager : NSObject
+ (instancetype)sharedInstance;
- (NSArray <PLSource *> *)sources;
- (void)addSourceWithArchiveType:(NSString *)archiveType repositoryURI:(NSString *)URI distribution:(NSString *)distribution components:(NSArray <NSString *> *_Nullable)components;
- (void)removeSource:(PLSource *)sourceToRemove;
- (PLSource *)sourceForPackage:(PLPackage *)package;
@end

NS_ASSUME_NONNULL_END
