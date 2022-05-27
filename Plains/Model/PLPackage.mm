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

@implementation PLPackage {
    pkgCache::PkgIterator _package;
    pkgCache::VerIterator _ver;
    pkgDepCache *_depCache;
    pkgRecords *_records;

    // Computed properties
    NSString *_longDescription;
    NSString *_maintainerName;
    NSString *_maintainerEmail;
    NSString *_authorName;
    NSString *_authorEmail;
    NSArray <NSString *> *_tags;
}

- (instancetype)initWithIterator:(pkgCache::VerIterator)iterator depCache:(pkgDepCache *)depCache records:(pkgRecords *)records {
    if (iterator.end()) {
        return NULL;
    }
    
    self = [super init];
    
    if (self) {
        _package = iterator.ParentPkg();
        _depCache = depCache;
        _records = records;
        _ver = iterator;

        const char *identifier = _package.Name();
        if (identifier == NULL) {
            return NULL;
        }

        _identifier = [NSString stringWithUTF8String:identifier];
        _installed = _package->CurrentVer != NULL;
        _essential = _package->Flags & pkgCache::Flag::Essential;
        _held = _package->SelectedState == pkgCache::State::Hold;
        _downloadSize = _ver->Size;
        _installedSize = _ver->InstalledSize;
    }
    
    return self;
}

- (pkgCache::PkgIterator)iterator {
    return _package;
}

- (pkgCache::VerIterator)verIterator {
    return _ver;
}

- (void)setHeld:(BOOL)held {
    _held = held;
    [[PLPackageManager sharedInstance] setPackage:self held:_held];
}

- (NSArray *)parseRFC822Address:(std::string)address {
    NSString *string = [NSString stringWithUTF8String:address.c_str()];
    
    if (!string) return NULL;
    
    NSRange emailStart = [string rangeOfString:@" <"];
    NSRange emailEnd = [string rangeOfString:@">"];
    if (emailStart.location != NSNotFound && emailEnd.location != NSNotFound) {
        NSString *name = [string substringToIndex:emailStart.location];
        NSRange emailRange = NSMakeRange(emailStart.location + emailStart.length, emailEnd.location - emailStart.location - emailStart.length);
        NSString *email = [string substringWithRange:emailRange];
        if (!name || !email) return @[string];
        return @[name, email];
    } else {
        return @[string];
    }
}

- (BOOL)hasTagline {
    return self.longDescription.length > self.shortDescription.length;
}

- (NSString *)longDescription {
    if (!_longDescription && !_ver.end()) {
        pkgRecords::Parser & parser = _records->Lookup(_ver.FileList());
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

- (NSString *)getField:(NSString *)field {
    if (!_ver.end()) {
        pkgCache::VerFileIterator itr = _ver.FileList();
        if (itr.end()) return NULL;
        
        pkgRecords::Parser &parser = _records->Lookup(itr);
        std::string result = parser.RecordField(field.UTF8String);
        if (!result.empty()) {
            return [NSString stringWithUTF8String:result.c_str()];
        }
    }
    return NULL;
}

- (id)objectForKeyedSubscript:(NSString *)key {
    return [self getField:key];
}

- (PLSource *)source {
    return [[PLSourceManager sharedInstance] sourceForPackage:self];
}

- (NSString *)installedSizeString {
    return [NSByteCountFormatter stringFromByteCount:self.installedSize countStyle:NSByteCountFormatterCountStyleFile];
}

- (NSString *)downloadSizeString {
    return [NSByteCountFormatter stringFromByteCount:self.downloadSize countStyle:NSByteCountFormatterCountStyleFile];
}

- (BOOL)hasUpdate {
    if (self.held) return false;
    
    pkgCache::VerIterator currentVersion = _package.CurrentVer();
    if (!currentVersion.end()) {
        return currentVersion != _ver;
    }
    return false;
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

- (NSArray <PLPackage *> *)lesserVersions {
    NSMutableArray *lesserVersions = [NSMutableArray new];
    NSString *comparisonVersion = self.installedVersion ?: self.version;
    for (pkgCache::VerIterator iterator = _package.VersionList(); !iterator.end(); iterator++) {
        NSString *otherVersion = [NSString stringWithUTF8String:iterator.VerStr()];
        if ([otherVersion isEqualToString:comparisonVersion]) continue;
        if ([comparisonVersion compareVersion:otherVersion] == NSOrderedDescending) {
            PLPackage *otherVersion = [[PLPackage alloc] initWithIterator:iterator depCache:_depCache records:_records];
            [lesserVersions addObject:otherVersion];
        }
    }
    return lesserVersions;
}

- (NSArray<PLPackage *> *)greaterVersions {
    NSMutableArray *greaterVersions = [NSMutableArray new];
    NSString *comparisonVersion = self.installedVersion ?: self.version;
    for (pkgCache::VerIterator iterator = _package.VersionList(); !iterator.end(); iterator++) {
        NSString *otherVersion = [NSString stringWithUTF8String:iterator.VerStr()];
        if ([otherVersion isEqualToString:comparisonVersion]) continue;
        if ([comparisonVersion compareVersion:otherVersion] == NSOrderedAscending) {
            PLPackage *otherVersion = [[PLPackage alloc] initWithIterator:iterator depCache:_depCache records:_records];
            [greaterVersions addObject:otherVersion];
        }
    }
    return greaterVersions;
}

- (void)fetchMaintainers {
    if (!_ver.end()) {
        pkgRecords::Parser &parser = _records->Lookup(_ver.FileList());
        std::string maintainer = parser.Maintainer();
        if (!maintainer.empty()) {
            NSArray *components = [self parseRFC822Address:maintainer];
            _maintainerName = components[0];
            if (components.count > 1) {
                _maintainerEmail = components[1];
            }
        }
        std::string author = parser.RecordField("Author");
        if (author.empty()) {
            _authorName = _maintainerName;
            _authorEmail = _maintainerEmail;
        } else {
            NSArray *components = [self parseRFC822Address:author];
            _authorName = components[0];
            if (components.count > 1) {
                _authorEmail = components[1];
            }
        }
    }
}

- (NSString *)authorName {
    if (!_authorName) {
        [self fetchMaintainers];
    }
    return _authorName;
}

- (NSString *)authorEmail {
    if (!_authorEmail) {
        [self fetchMaintainers];
    }
    return _authorEmail;
}

- (NSString *)maintainerName {
    if (!_maintainerName) {
        [self fetchMaintainers];
    }
    return _maintainerName;
}

- (NSString *)maintainerEmail {
    if (!_maintainerEmail) {
        [self fetchMaintainers];
    }
    return _maintainerEmail;
}

- (NSString *)name {
    return self[@"Name"] ?: _identifier;
}

- (NSString *)version {
    const char *versionChars = _ver.VerStr();
    if (versionChars == NULL) {
        return nil;
    }
    return [NSString stringWithUTF8String:versionChars];
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

- (NSString *)section {
    const char *sectionChars = _ver.Section();
    if (sectionChars == NULL) {
        return nil;
    }
    return [NSString stringWithUTF8String:sectionChars];
}

- (NSString *)shortDescription {
    if (_ver.end()) {
        return nil;
    }
    pkgCache::VerFileIterator itr = _ver.FileList();
    if (itr.end()) return nil;

    pkgRecords::Parser &parser = _records->Lookup(itr);
    std::string description = parser.ShortDesc();
    if (description.empty()) {
        return nil;
    }
    return [NSString stringWithUTF8String:description.c_str()];
}

- (NSURL *)iconURL {
    return [NSURL URLWithString:self[@"Icon"]];
}

- (NSURL *)depictionURL {
    return [NSURL URLWithString:self[@"Depiction"]];
}

- (NSURL *)nativeDepictionURL {
    return [NSURL URLWithString:self[@"Native-Depiction"]];
}

- (NSURL *)homepageURL {
    return [NSURL URLWithString:self[@"Homepage"]];
}

- (NSURL *)headerURL {
    return [NSURL URLWithString:self[@"Header"]];
}

- (NSArray *)depends {
    return [self _parseCommaSeparatedList:self[@"Depends"] ?: @""];
}

- (NSArray *)conflicts {
    return [self _parseCommaSeparatedList:self[@"Conflicts"] ?: @""];
}

- (NSArray <NSString *> *)tags {
    if (_tags == nil) {
        _tags = [self _parseCommaSeparatedList:self[@"Tag"] ?: @""];
    }
    return _tags;
}

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

- (uint16_t)role {
    for (NSString *tag in self.tags) {
        NSRange range = [tag rangeOfString:@"role::"];
        if (range.location != 0) {
            continue;
        }
        NSArray *roleOptions = @[@"user", @"enduser", @"hacker", @"developer", @"cydia"];
        NSString *rawRole = [tag substringFromIndex:range.length];
        switch ([roleOptions indexOfObject:rawRole]) {
        case 0:
        case 1:
            return 1;
        case 2:
            return 2;
        case 3:
            return 3;
        case 4:
            return 5;
        default:
            return 4;
        }
    }
    return 1;
}

- (BOOL)paid {
    return [self.tags containsObject:@"cydia::commercial"];
}

- (NSString *)_listFilePath {
    NSString *statePath = [[PLConfig sharedInstance] stringForKey:@"Dir::State::status"].stringByDeletingLastPathComponent;
    return [[statePath stringByAppendingPathComponent:@"info"] stringByAppendingFormat:@"%@.list", self.identifier];
}

- (nullable NSDate *)installedDate {
    NSDictionary <NSFileAttributeKey, id> *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:self._listFilePath error:nil];
    return attributes[NSFileModificationDate];
}

- (NSArray *)installedFiles {
    NSString *path = self._listFilePath;
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSError *readError = NULL;
        NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&readError];
        if (!readError) {
            return [contents componentsSeparatedByString:@"\n"];
        }
        return @[readError.localizedDescription];
    }
    return NULL;
}

@end
