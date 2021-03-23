//
//  PLPackage.h
//  Plains
//
//  Created by Wilson Styres on 3/4/21.
//

#import <Foundation/Foundation.h>

#include "apt-pkg/cachefile.h"
#include "apt-pkg/pkgrecords.h"

@class PLSource;

NS_ASSUME_NONNULL_BEGIN

@interface PLPackage : NSObject
@property NSString *name;
@property NSString *identifier;
@property BOOL installed;
@property uint16_t role;
- (id)initWithIterator:(pkgCache::PkgIterator)iterator depCache:(pkgDepCache *)depCache records:(pkgRecords *)records;
- (NSString *)packageDescription;
- (NSString *)section;
- (NSString *)installedVersion;
- (PLSource *)source;
- (NSString *)getField:(NSString *)field;
@end

NS_ASSUME_NONNULL_END
