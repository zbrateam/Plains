//
//  PLPackage.m
//  Plains
//
//  Created by Wilson Styres on 3/4/21.
//

#import "PLPackage.h"
#import "PLPackageManager.h"
#import "PLSourceManager.h"
#import "PLSource.h"
#import "PLConfig.h"
#import "NSString+Plains.h"
#import <Plains/Plains-Swift.h>

@implementation PLPackage {
    pkgDepCache *_depCache;
    pkgRecords *_records;

    // Computed properties
    NSString *_longDescription;
    PLEmail *_maintainer;
    PLEmail *_author;
    NSArray <NSString *> *_tags;
}

- (instancetype)initWithIterator:(pkgCache::VerIterator)iterator depCache:(pkgDepCache *)depCache records:(pkgRecords *)records {
    if (iterator.end()) {
        return NULL;
    }
    
    self = [super init];
    
    if (self) {
        _verIterator = iterator;
        _package = iterator.ParentPkg();
        _depCache = depCache;
        _records = records;

        const char *identifier = _package.Name();
        if (identifier == NULL) {
            return NULL;
        }
        _identifier = [NSString stringWithUTF8String:identifier];
    }
    
    return self;
}

#pragma mark - Versions

- (BOOL)hasUpdate {
    if (self.isHeld) {
        return NO;
    }
    pkgCache::VerIterator currentVersion = _package.CurrentVer();
    if (!currentVersion.end()) {
        return currentVersion != _verIterator;
    }
    return NO;
}

- (NSUInteger)numberOfVersions {
    NSUInteger count = 0;
    for (pkgCache::VerIterator iterator = _package.VersionList(); !iterator.end(); iterator++) count++;
    return count;
}

- (NSArray <PLPackage *> *)allVersions {
    NSMutableArray *allVersions = [NSMutableArray new];
    for (pkgCache::VerIterator iterator = _package.VersionList(); !iterator.end(); iterator++) {
        PLPackage *otherVersion = [[PLPackage alloc] initWithIterator:iterator depCache:_depCache records:_records];
        [allVersions addObject:otherVersion];
    }
    return allVersions;
}

#pragma mark - State

- (PLSource *)source {
    return [[PLSourceManager sharedInstance] sourceForPackage:self];
}

- (BOOL)isEssential {
    return (_package->Flags & pkgCache::Flag::Essential) == pkgCache::Flag::Essential;
}

- (BOOL)isHeld {
    return _package->SelectedState == pkgCache::State::Hold;
}

- (BOOL)isInstalled {
    return _package->CurrentVer != NULL;
}

#pragma mark - Fields

- (NSString *)getField:(NSString *)field {
    if (_verIterator.end()) {
        return nil;
    }
    pkgCache::VerFileIterator itr = _verIterator.FileList();
    if (itr.end()) {
        return nil;
    }

    pkgRecords::Parser &parser = _records->Lookup(itr);
    return [NSString plains_stringWithStdString:parser.RecordField(field.UTF8String)];
}

- (NSUInteger)downloadSize {
    return _verIterator->Size;
}

- (NSUInteger)installedSize {
    return _verIterator->InstalledSize;
}

- (nullable PLEmail *)author {
    if (!_author) {
        _author = [[PLEmail alloc] initWithRFC822Value:self[@"Author"]];
    }
    return _author;
}

- (nullable PLEmail *)maintainer {
    if (!_maintainer) {
        _maintainer = [[PLEmail alloc] initWithRFC822Value:self[@"Maintainer"]];
    }
    return _maintainer;
}

- (NSString *)architecture {
    return [NSString stringWithUTF8String:_verIterator.Arch()];
}

- (NSString *)version {
    return [NSString stringWithUTF8String:_verIterator.VerStr()];
}

- (NSString *)installedVersion {
    pkgCache::VerIterator installedVersion = _package.CurrentVer();
    if (installedVersion.end()) {
        return nil;
    }
    const char *installedVersionChars = installedVersion.VerStr();
    if (installedVersionChars == NULL) {
        return nil;
    }
    return [NSString stringWithUTF8String:installedVersionChars];
}

- (NSString *)longDescription {
    if (!_longDescription && !_verIterator.end()) {
        pkgRecords::Parser & parser = _records->Lookup(_verIterator.FileList());
        std::string description = parser.LongDesc();

        NSString *longDesc = [NSString stringWithUTF8String:description.c_str()];
        NSRange endOfFirstLine = [longDesc rangeOfString:@"\n"];
        if (endOfFirstLine.location != NSNotFound) {
            NSString *trimmed = [longDesc substringFromIndex:endOfFirstLine.location + 2];
            trimmed = [trimmed stringByReplacingOccurrencesOfString:@"\n " withString:@"\n"];
            _longDescription = [trimmed stringByReplacingOccurrencesOfString:@"\n.\n" withString:@"\n\n"];
        } else {
            _longDescription = longDesc;
        }
    }
    return _longDescription;
}

- (NSString *)shortDescription {
    if (_verIterator.end()) {
        return nil;
    }
    pkgCache::VerFileIterator itr = _verIterator.FileList();
    if (itr.end()) return nil;

    pkgRecords::Parser &parser = _records->Lookup(itr);
    std::string description = parser.ShortDesc();
    if (description.empty()) {
        return nil;
    }
    return [NSString stringWithUTF8String:description.c_str()];
}

- (NSString *)section {
    const char *section = _verIterator.Section();
    if (!section) {
        return nil;
    }
    return [NSString stringWithUTF8String:section];
}

- (NSArray <NSString *> *)tags {
    if (!_tags) {
        NSString *tags = self[@"Tag"];
        _tags = tags ? [self _parseCommaSeparatedList:tags] : @[];
    }
    return _tags;
}

#pragma mark - Helpers

- (NSArray <NSString *> *)_parseCommaSeparatedList:(NSString *)input {
    NSArray *items = [input componentsSeparatedByString:@","];
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *item in items) {
        // Trim leading space after comma if necessary
        NSString *value = item.length > 0 && [item characterAtIndex:0] == ' ' ? [item substringFromIndex:1] : item;
        [result addObject:value];
    }
    return result;
}

@end
