//
//  PLDatabase.h
//  Plains
//
//  Created by Wilson Styres on 2/27/21.
//

#import <Foundation/Foundation.h>

#include "apt-pkg/cachefile.h"
#include "apt-pkg/algorithms.h"

@class PLSource;
@class PLPackage;

NS_ASSUME_NONNULL_BEGIN

@interface PLDatabase : NSObject

+ (instancetype)sharedInstance;
- (void)import;
- (void)refreshSources;
- (pkgCacheFile &)cache;
- (pkgProblemResolver *)resolver;
- (NSArray <PLSource *> *)sources;
- (NSArray <PLPackage *> *)packages;
//- (void)fetchPackagesFromSource:(ZBSource *)source inSection:(NSString *_Nullable)section completion:(void (^)(NSArray <ZBPackage *> *packages))completion;
- (PLSource *)sourceFromID:(unsigned long)identifier;
@end

NS_ASSUME_NONNULL_END
