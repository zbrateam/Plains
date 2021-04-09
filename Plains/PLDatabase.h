//
//  PLDatabase.h
//  Plains
//
//  Created by Wilson Styres on 2/27/21.
//

#import <Foundation/Foundation.h>

#import "PLAcquireDelegate.h"

#include "apt-pkg/cachefile.h"
#include "apt-pkg/algorithms.h"

@class PLSource;
@class PLPackage;

NS_ASSUME_NONNULL_BEGIN

extern NSString* const PLDatabaseUpdateNotification;

@interface PLDatabase : NSObject

+ (instancetype)sharedInstance;
- (void)import;
- (void)refreshSources;
- (pkgCacheFile &)cache;
- (pkgProblemResolver *)resolver;
- (NSArray <PLSource *> *)sources;
- (NSArray <PLPackage *> *)packages;
- (NSArray <PLPackage *> *)updates;
- (void)fetchPackagesMatchingFilter:(BOOL (^)(PLPackage *package))filter completion:(void (^)(NSArray <PLPackage *> *packages))completion;
- (PLSource *)sourceFromID:(unsigned long)identifier;
- (void)startDownloads:(id<PLAcquireDelegate>)delegate;
@end

NS_ASSUME_NONNULL_END
