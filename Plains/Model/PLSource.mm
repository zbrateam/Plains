//
//  PLSource.m
//  Plains
//
//  Created by Wilson Styres on 3/1/21.
//

#import "PLSource.h"
#import "PLPackageManager.h"
#import "PLPackage.h"

#import <UIKit/UIImage.h>

#include "apt-pkg/metaindex.h"
#include "apt-pkg/debmetaindex.h"
#include "apt-pkg/acquire.h"
#include "apt-pkg/acquire-item.h"
#include "apt-pkg/configuration.h"
#include "apt-pkg/strutl.h"
#include "apt-pkg/fileutl.h"
#include "apt-pkg/tagfile.h"

@interface PLSource () {
    NSDictionary *_sections;
}
@end

@implementation PLSource

+ (UIImage *)imageForSection:(NSString *)section {
    if (!section) return [UIImage imageNamed:@"Unknown"];
    
    NSString *imageName = [section stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    if ([imageName containsString:@"("]) {
        NSArray *components = [imageName componentsSeparatedByString:@"_("];
        if ([components count] < 2) {
            components = [imageName componentsSeparatedByString:@"("];
        }
        imageName = components[0];
    }
    
    UIImage *sectionImage = [UIImage imageNamed:imageName] ?: [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"/Applications/Zebra.app/Sections/%@.png", imageName]] ?: [UIImage imageNamed:@"Unknown"];
    return sectionImage;
}

- (id)initWithMetaIndex:(metaIndex *)index {
    self = [super init];
    
    if (self) {
        _index = index;
        
        NSString *URIString = [self stringFromStdString:index->GetURI()];
        if (URIString) {
            _URI = [NSURL URLWithString:URIString];
        }
        
        _distribution = [self stringFromStdString:index->GetDist()];
        
        if (![_distribution isEqualToString:@"/"]) {
            if ([_distribution hasSuffix:@"/"]) {
                URIString = [URIString stringByAppendingString:_distribution];
            } else {
                URIString = [URIString stringByAppendingFormat:@"dists/%@/", _distribution];
            }
        }
        NSMutableCharacterSet *allowed = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
        [allowed removeCharactersInString:@"_"];
        URIString = [URIString stringByAddingPercentEncodingWithAllowedCharacters:allowed];
        
        self.baseURI = [NSURL URLWithString:URIString];
        
        NSString *schemeless = _URI.scheme ? [[URIString stringByReplacingOccurrencesOfString:_URI.scheme withString:@""] substringFromIndex:3] : URIString; //Removes scheme and ://
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
        if (releaseIndex) {
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
                }
                if (section.Find("origin", start, end)) {
                    self.origin = [[NSString alloc] initWithBytes:start length:end - start encoding:NSUTF8StringEncoding];
                }
            }
            
            debReleaseIndexPrivate *privateIndex = releaseIndex->d;
            std::vector<debReleaseIndexPrivate::debSectionEntry> entries = privateIndex->DebEntries;
            
            NSMutableArray *comps = [NSMutableArray new];
            for (debReleaseIndexPrivate::debSectionEntry entry : entries) {
                std::string entryPath = entry.sourcesEntry;
                if (!entryPath.empty()) {
                    NSString *filePath = [NSString stringWithUTF8String:entryPath.c_str()];
                    NSArray *components = [filePath componentsSeparatedByString:@":"];
                    _entryFilePath = components[0];
                }
                
                std::string name = entry.Name;
                if (!name.empty()) {
                    [comps addObject:[NSString stringWithUTF8String:name.c_str()]];
                }
            }
            _components = comps;
        }
    }
    
    self.remote = YES;
    
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

- (NSURL *)iconURL {
#if TARGET_OS_MACCATALYST
    return [self.baseURI URLByAppendingPathComponent:@"RepoIcon.png"];
#else
    return [self.baseURI URLByAppendingPathComponent:@"CydiaIcon.png"];
#endif
}

- (NSString *)origin {
    if (_origin) {
        return _origin;
    }
    return _URI.absoluteString;
}

- (NSComparisonResult)compareByOrigin:(PLSource *)other {
    return [self.origin localizedCaseInsensitiveCompare:other.origin];
}

- (NSDictionary *)sections {
    if (!_sections || _sections.count == 0) {
        PLPackageManager *database = [PLPackageManager sharedInstance];
        NSArray *packages = [database packages];
        NSMutableDictionary *tempSections = [NSMutableDictionary new];
        
        for (PLPackage *package in packages) {
            if (package.source != self) continue;
            
            NSString *sectionName = package.section;
            NSString *sectionKey = sectionName ?: @"Uncategorized";
            
            NSNumber *count = tempSections[sectionKey];
            if (count) {
                tempSections[sectionKey] = @(count.intValue + 1);
            } else {
                tempSections[sectionKey] = @(1);
            }
        }
        _sections = tempSections;
    }
    return _sections;
}

- (BOOL)canRemove {
    return [self.entryFilePath hasSuffix:@"zebra.sources"] && ![self.UUID isEqualToString:@"getzbra.com_repo_._"];
}

- (BOOL)isEqualToSource:(PLSource *)other {
    return [self.type isEqualToString:other.type] && [self.URI isEqual:other.URI] && [self.distribution isEqualToString:other.distribution] && [self.components isEqualToArray:other.components];
}

- (BOOL)isEqual:(id)other {
    if (other == self) {
        return YES;
    } else if (![other isKindOfClass:[PLSource class]]) {
        return NO;
    } else {
        return [self isEqualToSource:other];
    }
}

- (NSUInteger)hash {
    return self.type.hash ^ self.URI.hash ^ self.distribution.hash ^ self.components.hash;
}

@end