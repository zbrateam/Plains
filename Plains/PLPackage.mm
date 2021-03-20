//
//  PLPackage.m
//  Plains
//
//  Created by Wilson Styres on 3/4/21.
//

#import "PLPackage.h"

@interface PLPackage () {
    pkgCache::PkgIterator *package;
    pkgDepCache *depCache;
    pkgRecords *records;
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
        
        std::string identifier = package->Name();
        const char *s = identifier.c_str();
        if (s == NULL) return NULL;
        _identifier = [NSString stringWithUTF8String:s];
        
        _name = self[@"Name"] ?: _identifier;
    }
    
    return self;
}

- (void)dealloc {
    delete package;
}

- (NSString *)packageDescription {
    pkgCache::VerIterator ver = (*depCache)[*package].CandidateVerIter(*depCache);

    if (!ver.end()) {
        pkgCache::DescIterator Desc = ver.TranslatedDescription();
        pkgRecords::Parser & parser = records->Lookup(Desc.FileList());
        std::string description = parser.LongDesc();
        return [NSString stringWithUTF8String:description.c_str()];
    } else {
        return @"";
    }
}

- (NSString *)section {
    pkgCache::VerIterator ver = (*depCache)[*package].CandidateVerIter(*depCache);
    if (!ver.end()) {
        const char *s = ver.Section();
        if (s == NULL)
            return @"Unknown";
        return [NSString stringWithUTF8String:s];
    }

    return @"Unknown";
}

- (NSString *)installedVersion {
    const char *s = package->CurrentVer().VerStr();
    
    if (s == NULL)
        return @"";
    return [NSString stringWithUTF8String:s];
}

- (NSString *)getField:(NSString *)field {
    pkgCache::VerIterator ver = (*depCache)[*package].CandidateVerIter(*depCache);
    if (!ver.end()) {
        pkgRecords::Parser &parser = records->Lookup(ver.FileList());
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

@end
