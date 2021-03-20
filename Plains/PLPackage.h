//
//  PLPackage.h
//  Plains
//
//  Created by Wilson Styres on 3/4/21.
//

#import <Foundation/Foundation.h>

#include "apt-pkg/cachefile.h"
#include "apt-pkg/pkgrecords.h"

NS_ASSUME_NONNULL_BEGIN

@interface PLPackage : NSObject
@property BOOL installed;
- (id)initWithIterator:(pkgCache::PkgIterator)iterator depCache:(pkgDepCache *)depCache records:(pkgRecords *)records;
- (NSString *)name;
- (NSString *)packageDescription;
- (NSString *)section;
- (NSString *)installedVersion;
@end

NS_ASSUME_NONNULL_END
