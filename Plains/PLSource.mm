//
//  PLSource.m
//  Plains
//
//  Created by Wilson Styres on 3/1/21.
//

#import "PLSource.h"

#include "apt-pkg/metaindex.h"
#include "apt-pkg/debmetaindex.h"
#include "apt-pkg/acquire.h"
#include "apt-pkg/acquire-item.h"
#include "apt-pkg/configuration.h"
#include "apt-pkg/strutl.h"
#include "apt-pkg/fileutl.h"
#include "apt-pkg/tagfile.h"

@implementation PLSource

- (id)initWithMetaIndex:(metaIndex *)index {
    self = [super init];
    
    if (self) {
        NSString *URIString = [self stringFromStdString:index->GetURI()];
        if (URIString) {
            _URI = [NSURL URLWithString:URIString];
        }
        
        _distribution = [self stringFromStdString:index->GetDist()];
        
        NSString *schemeless = _URI.scheme ? [[URIString stringByReplacingOccurrencesOfString:_URI.scheme withString:@""] substringFromIndex:3] : URIString; //Removes scheme and ://
        if ([_distribution isEqualToString:@"/"]) {
            ; // pass-through
        }
        else if ([_distribution hasSuffix:@"/"]) {
            schemeless = [schemeless stringByAppendingString:_distribution];
        } else {
            schemeless = [schemeless stringByAppendingFormat:@"dists/%@/", _distribution];
        }
        _UUID = [schemeless stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
        
        _type = [self stringFromCString:index->GetType()];
        self.origin = [self stringFromStdString:index->GetOrigin()];
        self.label = [self stringFromStdString:index->GetLabel()];
        self.version = [self stringFromStdString:index->GetVersion()];
        self.codename = [self stringFromStdString:index->GetCodename()];
        self.suite = [self stringFromStdString:index->GetSuite()];
        self.releaseNotes = [self stringFromStdString:index->GetReleaseNotes()];
        self.defaultPin = index->GetDefaultPin();
        self.trusted = index->IsTrusted();
        
        debReleaseIndex *releaseIndex = (debReleaseIndex *)index;
        if (releaseIndex != NULL) {
            std::string listsDir = _config->FindDir("Dir::State::lists");
            std::string metaIndexURI = std::string([_UUID UTF8String]);
            std::string releaseFilePath = listsDir + metaIndexURI + "Release";
            
            FileFd releaseFile;
            if (releaseFile.Open(releaseFilePath, FileFd::ReadOnly)) {
                pkgTagFile tagFile = pkgTagFile(&releaseFile);
                pkgTagSection section;
                tagFile.Step(section);
                
                const char *start, *end;
                if (section.Find("label", start, end)) {
                    self.label = [[NSString alloc] initWithBytes:start length:end - start encoding:NSUTF8StringEncoding];
                    NSLog(@"[Plains] New Label: %@", self.label);
                }
                if (section.Find("origin", start, end)) {
                    self.origin = [[NSString alloc] initWithBytes:start length:end - start encoding:NSUTF8StringEncoding];
                    NSLog(@"[Plains] New Origin: %@", self.origin);
                }
            }
        }
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
