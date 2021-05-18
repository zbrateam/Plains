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
#import "NSString+Plains.h"

@interface PLPackage () {
    pkgCache::PkgIterator package;
    pkgCache::VerIterator ver;
    pkgDepCache *depCache;
    pkgRecords *records;
    
    // Computed properties
    BOOL parsed;
    NSString *longDescription;
    NSString *maintainerName;
    NSString *maintainerEmail;
}
@end

@implementation PLPackage

- (id)initWithIterator:(pkgCache::VerIterator)iterator depCache:(pkgDepCache *)depCache records:(pkgRecords *)records {
    if (iterator.end()) return NULL;
    
    self = [super init];
    
    if (self) {
        self->package = iterator.ParentPkg();
        _installed = self->package->CurrentVer != 0;
        self->depCache = depCache;
        self->records = records;
        self->ver = iterator;
        if (self->ver.end()) return NULL;
        
        const char *identifier = package.Name();
        if (identifier != NULL) {
            _identifier = [NSString stringWithUTF8String:identifier];
        } else {
            return NULL;
        }
        
        _name = self[@"Name"] ?: _identifier;
        
        const char *versionChars = ver.VerStr();
        if (versionChars != NULL) {
            _version = [NSString stringWithUTF8String:versionChars];
        } else {
            return NULL;
        }
        
        pkgCache::VerIterator installedVersion = self->package.CurrentVer();
        if (!installedVersion.end()) {
            const char *installedVersionChars = installedVersion.VerStr();
            if (installedVersionChars != NULL) {
                _installedVersion = [NSString stringWithUTF8String:installedVersionChars];
            }
        }
        
        const char *sectionChars = self->ver.Section();
        if (sectionChars != NULL) {
            _section = [NSString stringWithUTF8String:sectionChars];
        }
        
        _essential = self->package->Flags & pkgCache::Flag::Essential;
        
        _downloadSize = self->ver->Size;
        _installedSize = self->ver->InstalledSize;
        
        pkgRecords::Parser &parser = records->Lookup(self->ver.FileList());
        std::string author = parser.RecordField("Author");
        if (!author.empty()) {
            NSArray *components = [self parseMIMEAddress:author];
            if (components) {
                _authorName = components[0];
                if (components.count > 1) {
                    _authorEmail = components[1];
                }
            }
        }
        
        std::string icon = parser.RecordField("Icon");
        if (!icon.empty()) {
            _iconURL = [NSURL URLWithString:[NSString stringWithUTF8String:icon.c_str()]];
        }
        
        std::string description = parser.ShortDesc();
        if (!description.empty()) {
            _shortDescription = [NSString stringWithUTF8String:description.c_str()];
        }
        
        // Set default values for roles
        _role = 0;
        _paid = false;
        
        NSString *rawTag = self[@"Tag"];
        if (rawTag) {
            NSArray *tags = [rawTag componentsSeparatedByString:@", "];
            if (tags.count == 0) tags = [rawTag componentsSeparatedByString:@","];
            
            // Parse out tags
            for (NSString *tag in tags) {
                NSRange range;
                if ((range = [tag rangeOfString:@"role::"]).location != NSNotFound) { // Mirror Cydia's "role" tags
                    NSArray *roleOptions = @[@"user", @"enduser", @"hacker", @"developer", @"cydia"];
                    NSString *rawRole = [tag substringFromIndex:range.length];
                    switch ([roleOptions indexOfObject:rawRole]) {
                        case 0:
                        case 1:
                            _role = 1;
                            break;
                        case 2:
                            _role = 2;
                            break;
                        case 3:
                            _role = 3;
                            break;
                        case 4:
                            _role = 5;
                            break;
                        default:
                            _role = 4;
                            break;
                    }
                } else if ((range = [tag rangeOfString:@"cydia::"]).location != NSNotFound) {
                    NSArray *cydiaOptions = @[@"commercial"];
                    NSString *rawCydia = [tag substringFromIndex:range.length];
                    switch ([cydiaOptions indexOfObject:rawCydia]) {
                        case 0:
                            _paid = true;
                            break;
                        default:
                            break;
                    }
                }
            }
        }
    }
    
    return self;
}

- (pkgCache::PkgIterator)iterator {
    return self->package;
}

- (pkgCache::VerIterator)verIterator {
    return self->ver;
}

- (NSArray *)parseMIMEAddress:(std::string)address {
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
    if (!self->longDescription && !self->ver.end()) {
        pkgCache::DescIterator Desc = ver.TranslatedDescription();
        pkgRecords::Parser & parser = records->Lookup(Desc.FileList());
        std::string description = parser.LongDesc();
        
        NSString *longDesc = [NSString stringWithUTF8String:description.c_str()];
        NSRange endOfFirstLine = [longDesc rangeOfString:@"\n"];
        if (endOfFirstLine.location != NSNotFound) {
            NSString *trimmed = [longDesc substringFromIndex:endOfFirstLine.location + 2];
            trimmed = [trimmed stringByReplacingOccurrencesOfString:@"\n " withString:@"\n"];
            self->longDescription = [trimmed stringByReplacingOccurrencesOfString:@"\n.\n" withString:@"\n\n"];
        } else {
            self->longDescription = longDesc;
        }
    }
    return self->longDescription;
}

- (NSString *)getField:(NSString *)field {
    if (!self->ver.end()) {
        pkgRecords::Parser &parser = records->Lookup(self->ver.FileList());
        std::string result = parser.RecordField(field.UTF8String);
        if (!result.empty()) {
            return [NSString stringWithUTF8String:result.c_str()];
        }
    }
    return NULL;
}

- (PLSource *)source {
    return [[PLSourceManager sharedInstance] sourceForPackage:self];
}

- (NSString * _Nullable)installedSizeString {
    return [NSByteCountFormatter stringFromByteCount:self.installedSize countStyle:NSByteCountFormatterCountStyleFile];
}

- (NSString *)downloadSizeString {
    return [NSByteCountFormatter stringFromByteCount:self.downloadSize countStyle:NSByteCountFormatterCountStyleFile];
}

- (id)objectForKeyedSubscript:(NSString *)key {
    return [self getField:key];
}

- (BOOL)hasUpdate {
    pkgCache::VerIterator currentVersion = package.CurrentVer();
    if (!currentVersion.end()) {
        return currentVersion != self->ver;
    }
    return false;
}

- (NSUInteger)numberOfVersions {
    NSUInteger count = 0;
    for (pkgCache::VerIterator iterator = package.VersionList(); !iterator.end(); iterator++) count++;
    return count;
}

- (NSArray <PLPackage *> *)allVersions {
    NSMutableArray *allVersions = [NSMutableArray new];
    for (pkgCache::VerIterator iterator = package.VersionList(); !iterator.end(); iterator++) {
        PLPackage *otherVersion = [[PLPackage alloc] initWithIterator:iterator depCache:self->depCache records:self->records];
        [allVersions addObject:otherVersion];
    }
    return allVersions;
}

- (NSArray <PLPackage *> *)lesserVersions {
    NSMutableArray *lesserVersions = [NSMutableArray new];
    NSString *comparisonVersion = self.installedVersion ?: self.version;
    for (pkgCache::VerIterator iterator = package.VersionList(); !iterator.end(); iterator++) {
        NSString *otherVersion = [NSString stringWithUTF8String:iterator.VerStr()];
        if ([otherVersion isEqualToString:comparisonVersion]) continue;
        if ([comparisonVersion compareVersion:otherVersion] == NSOrderedDescending) {
            PLPackage *otherVersion = [[PLPackage alloc] initWithIterator:iterator depCache:self->depCache records:self->records];
            [lesserVersions addObject:otherVersion];
        }
    }
    return lesserVersions;
}

- (NSArray<PLPackage *> *)greaterVersions {
    NSMutableArray *greaterVersions = [NSMutableArray new];
    NSString *comparisonVersion = self.installedVersion ?: self.version;
    for (pkgCache::VerIterator iterator = package.VersionList(); !iterator.end(); iterator++) {
        NSString *otherVersion = [NSString stringWithUTF8String:iterator.VerStr()];
        if ([otherVersion isEqualToString:comparisonVersion]) continue;
        if ([comparisonVersion compareVersion:otherVersion] == NSOrderedAscending) {
            PLPackage *otherVersion = [[PLPackage alloc] initWithIterator:iterator depCache:self->depCache records:self->records];
            [greaterVersions addObject:otherVersion];
        }
    }
    return greaterVersions;
}

- (void)fetchMaintainer {
    if (!self->ver.end()) {
        pkgRecords::Parser &parser = records->Lookup(self->ver.FileList());
        std::string maintainer = parser.Maintainer();
        if (!maintainer.empty()) {
            NSArray *components = [self parseMIMEAddress:maintainer];
            self->maintainerName = components[0];
            if (components.count > 1) {
                self->maintainerEmail = components[1];
            }
        }
    }
}

- (NSString *)maintainerName {
    if (!self->maintainerName) {
        [self fetchMaintainer];
    }
    return self->maintainerName;
}

- (NSString *)maintainerEmail {
    if (!self->maintainerEmail) {
        [self fetchMaintainer];
    }
    return self->maintainerEmail;
}

- (NSURL *)depictionURL {
    NSString *urlString = self[@"Depiction"];
    if (urlString) {
        return [NSURL URLWithString:urlString];
    }
    return NULL;
}

- (NSURL *)homepageURL {
    NSString *urlString = self[@"Homepage"];
    if (urlString) {
        return [NSURL URLWithString:urlString];
    }
    return NULL;
}

- (NSArray *)depends {
    NSString *dependsString = self[@"Depends"];
    if (dependsString) {
        NSArray *depends = [dependsString componentsSeparatedByString:@", "];
        if ([depends[0] containsString:@","]) depends = [dependsString componentsSeparatedByString:@","];
        return depends;
    }
    return NULL;
}

- (NSArray *)conflicts {
    NSString *conflictsString = self[@"Conflicts"];
    if (conflictsString) {
        NSArray *conflicts = [conflictsString componentsSeparatedByString:@", "];
        if ([conflicts[0] containsString:@","]) conflicts = [conflictsString componentsSeparatedByString:@","];
        return conflicts;
    }
    return NULL;
}

-(NSArray *)installedFiles {
#if TARGET_OS_MACCATALYST
    NSString *prefix = @"/opt/procursus/";
#else
    NSString *prefix = @"/";
#endif
    NSString *path = [NSString stringWithFormat:@"%@var/lib/dpkg/info/%@.list", prefix, self.identifier];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSError *readError = NULL;
        NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&readError];
        if (!readError) {
            return [contents componentsSeparatedByString:@"\n"];
        }
        return @[readError.localizedDescription];
    }
    return @[@"No files found"];
}


// Parses fields that are needed for the depiction (not needed for the cells)
- (void)parse {
    pkgRecords::Parser &parser = records->Lookup(self->ver.FileList());
}

@end
