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
    }
    
    return self;
}

- (void)dealloc {
    delete package;
}

- (NSString *)name {
    pkgCache::VerIterator ver = (*depCache)[*package].CandidateVerIter(*depCache);
    if (!ver.end()) {
        pkgRecords::Parser & parser = records->Lookup(ver.FileList());
        std::string name = parser.RecordField("Name");
        if (name.empty()) return self.identifier;
        return [NSString stringWithUTF8String:name.c_str()];
    }
    return self.identifier;
}

- (NSString *)identifier {
    std::string identifier = package->Name();
    const char *s = identifier.c_str();

    if (s == NULL)
        return @"";
    return [NSString stringWithUTF8String:s];
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

@end
