//
//  PLPackage.m
//  Plains
//
//  Created by Wilson Styres on 3/4/21.
//

#import "PLPackage.h"
#import "PLDatabase.h"
#import "PLSource.h"

#import <UIKit/UIImageView.h>

@interface PLPackage () {
    pkgCache::PkgIterator *package;
    pkgCache::VerIterator ver;
    pkgDepCache *depCache;
    pkgRecords *records;
    
    // Computed properties
    NSString *longDescription;
    NSString *maintainerName;
    NSString *maintainerEmail;
}
@end

@implementation PLPackage

- (id)initWithIterator:(pkgCache::PkgIterator)iterator depCache:(pkgDepCache *)depCache records:(pkgRecords *)records {
    if (iterator.end()) return NULL;
    
    self = [super init];
    
    if (self) {
        _installed = iterator->CurrentVer != 0;
        self->package = new pkgCache::PkgIterator(iterator);
        self->depCache = depCache;
        self->records = records;
        self->ver = depCache->GetPolicy().GetCandidateVer(iterator);
        if (self->ver.end()) return NULL;
        
        const char *identifier = package->Name();
        if (identifier != NULL) {
            _identifier = [NSString stringWithUTF8String:identifier];
        } else {
            return NULL;
        }
        
        _name = self[@"Name"] ?: _identifier;
        
        const char *versionChars = self->ver.VerStr();
        if (versionChars != NULL) {
            _version = [NSString stringWithUTF8String:versionChars];
        } else {
            return NULL;
        }
        
        pkgCache::VerIterator installedVersion = iterator.CurrentVer();
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
        
        _essential = iterator->Flags & pkgCache::Flag::Essential;
        
        _downloadSize = self->ver->Size;
        _installedSize = self->ver->InstalledSize;
        
        pkgRecords::Parser &parser = records->Lookup(self->ver.FileList());
        std::string author = parser.RecordField("Author");
        if (!author.empty()) {
            NSArray *components = [self parseMIMEAddress:author];
            _authorName = components[0];
            if (components.count > 1) {
                _authorEmail = components[1];
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

- (void)dealloc {
    delete package;
}

- (NSArray *)parseMIMEAddress:(std::string)address {
    NSString *string = [NSString stringWithUTF8String:address.c_str()];
    
    NSRange emailStart = [string rangeOfString:@" <"];
    NSRange emailEnd = [string rangeOfString:@">"];
    if (emailStart.location != NSNotFound && emailEnd.location != NSNotFound) {
        NSString *name = [string substringToIndex:emailStart.location];
        NSRange emailRange = NSMakeRange(emailStart.location + emailStart.length, emailEnd.location - emailStart.location - emailStart.length);
        NSString *email = [string substringWithRange:emailRange];
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
            self->longDescription = [trimmed stringByReplacingOccurrencesOfString:@"\n " withString:@"\n"];
        } else {
            self->longDescription = longDesc;
        }
    }
    return self->longDescription;
}

- (NSString *)shortDescription {
    if (!self->shortDescription && !self->ver.end()) {
        pkgCache::DescIterator Desc = ver.TranslatedDescription();
        pkgRecords::Parser & parser = records->Lookup(Desc.FileList());
        
    }
    return self->shortDescription;
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
    pkgCache::PkgFileIterator file = self->ver.FileList().File();
    return [[PLDatabase sharedInstance] sourceFromID:file->ID];
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
    pkgCache::VerIterator currentVersion = package->CurrentVer();
    if (!currentVersion.end()) {
        return self->ver != currentVersion;
    }
    return false;
}

- (void)fetchMaintainer {
    if (!self->ver.end()) {
        pkgRecords::Parser &parser = records->Lookup(self->ver.FileList());
        std::string maintainer = parser.RecordField("Maintainer");
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

// Parses fields that aren't of immediate need
- (void)parse {
    pkgRecords::Parser &parser = records->Lookup(self->ver.FileList());
}

@end
