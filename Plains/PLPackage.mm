//
//  PLPackage.m
//  Plains
//
//  Created by Wilson Styres on 3/4/21.
//

#import "PLPackage.h"

#include "apt-pkg/cachefile.h"
#include "apt-pkg/pkgrecords.h"

@interface PLPackage () {
    pkgCache::PkgIterator *package;
    pkgDepCache *depCache;
    pkgRecords *records;
}
@end

@implementation PLPackage

- (id)initWithIterator:(pkgCache::PkgIterator &)iterator depCache:(pkgDepCache *)depCache records:(pkgRecords *)records {
    if (iterator.end()) return NULL;
    
    self = [super init];
    
    if (self) {
//        std::string name = iterator.FullName();
//        NSLog(@"[Plains] My full name is: %s", name.c_str());
        
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
    std::string name = package->FullName(true);
    const char *s = name.c_str();

    if (s == NULL)
        return @"";
    std::string str = std::string(s);
    return [NSString stringWithUTF8String:str.c_str()];
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
        if (s != NULL)
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

- (NSString *)stringFromStdString:(std::string)string {
    const char *cString = string.c_str();
    return [self stringFromCString:cString];
}

- (NSString *)stringFromCString:(const char *)cString {
    if (cString == NULL) return NULL;
    
    return [NSString stringWithUTF8String:cString];
}

@end
