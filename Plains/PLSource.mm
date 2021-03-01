//
//  PLSource.m
//  Plains
//
//  Created by Wilson Styres on 3/1/21.
//

#import "PLSource.h"

#include "apt-pkg/metaindex.h"

@implementation PLSource

- (id)initWithMetaIndex:(metaIndex *)index {
    self = [super init];
    
    if (self) {
        NSString *URIString = [self stringFromStdString:index->GetURI()];
        if (URIString) {
            self.URI = [NSURL URLWithString:URIString];
        }
        
        self.distribution = [self stringFromStdString:index->GetDist()];
        self.type = [self stringFromCString:index->GetType()];
        self.origin = [self stringFromStdString:index->GetOrigin()];
        self.label = [self stringFromStdString:index->GetLabel()];
        self.version = [self stringFromStdString:index->GetVersion()];
        self.codename = [self stringFromStdString:index->GetCodename()];
        self.suite = [self stringFromStdString:index->GetSuite()];
        self.releaseNotes = [self stringFromStdString:index->GetReleaseNotes()];
        self.defaultPin = index->GetDefaultPin();
        self.trusted = index->IsTrusted();
    }
    
    return self;
}

- (NSString *)stringFromStdString:(std::string)string {
    const char *cString = string.c_str();
    return [self stringFromCString:cString];
}

- (NSString *)stringFromCString:(const char *)cString {
    if (cString != 0 && cString[0] != '\0') {
        return [NSString stringWithUTF8String:cString];
    }
    return NULL;
}

@end
