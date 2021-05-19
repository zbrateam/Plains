//
//  PLPackageManager.h
//  Plains
//
//  Created by Wilson Styres on 2/27/21.
//

#import <Foundation/Foundation.h>

#import <Plains/Delegates/PLConsoleDelegate.h>

#include "apt-pkg/cachefile.h"
#include "apt-pkg/algorithms.h"
#include "apt-pkg/sourcelist.h"

@class PLSource;
@class PLPackage;

NS_ASSUME_NONNULL_BEGIN

extern NSString* const PLDatabaseImportNotification;
extern NSString* const PLDatabaseRefreshNotification;

@interface PLPackageManager : NSObject
+ (instancetype)sharedInstance;
- (void)import;
- (pkgCacheFile &)cache;
- (pkgProblemResolver *)resolver;
- (NSArray <PLPackage *> *)packages;
- (NSArray <PLPackage *> *)updates;
- (void)fetchPackagesMatchingFilter:(BOOL (^)(PLPackage *package))filter completion:(void (^)(NSArray <PLPackage *> *packages))completion;
- (void)downloadAndPerform:(id<PLConsoleDelegate>)delegate;
- (void)searchForPackagesWithNamePrefix:(NSString *)prefix completion:(void (^)(NSArray <PLPackage *> *packages))completion;
- (void)searchForPackagesWithName:(NSString *)prefix completion:(void (^)(NSArray <PLPackage *> *packages))completion;
- (NSString *)candidateVersionForPackage:(PLPackage *)package;
- (PLPackage *)findPackage:(PLPackage *)package;
- (PLPackage *)addDebFile:(NSURL *)path;
@end

NS_ASSUME_NONNULL_END
