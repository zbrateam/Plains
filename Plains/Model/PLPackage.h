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
@property (nonatomic) NSString *authorName;
@property (nonatomic) NSString *authorEmail;
@property (nonatomic) NSUInteger downloadSize;
@property (nonatomic) NSURL *_Nullable iconURL;
@property (nonatomic) NSString *identifier;
@property (nonatomic) NSUInteger installedSize;
@property (nonatomic) NSString *installedVersion;
@property (nonatomic) NSString *name;
@property (nonatomic) uint16_t role;
@property (nonatomic) NSString *section;
@property (nonatomic) NSString *shortDescription;
@property (nonatomic) NSString *uuid;
@property (nonatomic) NSString *version;
@property (readonly) BOOL installed;
@property (readonly) BOOL paid;
@property (readonly) BOOL essential;

- (id)initWithIterator:(pkgCache::PkgIterator)iterator depCache:(pkgDepCache *)depCache records:(pkgRecords *)records;
- (NSString *)getField:(NSString *)field;

- (PLSource *)source;
- (NSString * _Nullable)installedSizeString;
- (NSString *)downloadSizeString;
- (BOOL)hasUpdate;
- (BOOL)hasTagline;
- (pkgCache::PkgIterator)iterator;
- (pkgCache::VerIterator)verIterator;
- (NSArray <PLPackage *> *)allVersions;

// Computed properties
- (NSURL *)depictionURL;
- (NSString *)longDescription;
- (NSString *)maintainerName;
- (NSString *)maintainerEmail;
- (NSArray *)depends;
- (NSArray *)conflicts;
@end

NS_ASSUME_NONNULL_END