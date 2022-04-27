//
//  PLSource.m
//  Plains
//
//  Created by Wilson Styres on 3/1/21.
//

#import "PLSource.h"
#import "PLPackageManager.h"
#import "PLPackage.h"
#import "PLConfig.h"

#include <sys/stat.h>

PL_APT_PKG_IMPORTS_BEGIN
#include "apt-pkg/metaindex.h"
#include "apt-pkg/debmetaindex.h"
#include "apt-pkg/acquire.h"
#include "apt-pkg/acquire-item.h"
#include "apt-pkg/configuration.h"
#include "apt-pkg/strutl.h"
#include "apt-pkg/fileutl.h"
#include "apt-pkg/tagfile.h"
PL_APT_PKG_IMPORTS_END

@interface PLSource () {
    NSDictionary *_sections;
}
@end

@implementation PLSource

- (id)initWithMetaIndex:(metaIndex *)index {
    self = [super init];
    
    if (self) {
        _index = index;
        
        NSString *URIString = [self stringFromStdString:index->GetURI()];
        if (URIString) {
            _URI = [NSURL URLWithString:URIString];
        }

        // Get an index target for this source. We just need the first one of matching type, since
        // we only care about grabbing the base URI, which contains the dist but not the component.
        for (IndexTarget target : index->GetIndexTargets()) {
            if (strcmp(index->GetType(), target.Option(IndexTarget::TARGET_OF).c_str()) == 0) {
                std::string baseURI = target.Option(IndexTarget::BASE_URI);
                if (!baseURI.empty()) {
                    URIString = [self stringFromStdString:baseURI];
                    break;
                }
            }
        }
        _UUID = [self stringFromStdString:URItoFileName(URIString.UTF8String)];
        self.baseURI = [NSURL URLWithString:URIString];

        _distribution = [self stringFromStdString:index->GetDist()];
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
            std::string errorText;

            if (stat(releaseFilePath.c_str(), NULL) == 0) {
                _index->Load(releaseFilePath, &errorText);
                self.label = [self stringFromStdString:_index->GetLabel()];
                self.origin = [self stringFromStdString:_index->GetOrigin()];

                debReleaseIndexPrivate *privateIndex = releaseIndex->d;
                std::vector<debReleaseIndexPrivate::debSectionEntry> entries = privateIndex->DebEntries;

                NSMutableArray <NSString *> *comps = [NSMutableArray array];
                NSMutableArray <NSString *> *architectures = [NSMutableArray array];
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

                    for (std::string architecture : entry.Architectures) {
                        [architectures addObject:[NSString stringWithUTF8String:architecture.c_str()]];
                    }
                }
                _components = comps;
                _architectures = architectures;
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

- (NSURL *)iconURL {
    NSString *arch = self.architectures.firstObject ?: [[PLConfig sharedInstance] stringForKey:@"APT::Architecture"];
    NSString *iconName = [arch isEqualToString:@"iphoneos-arm"] ? @"CydiaIcon.png" : @"RepoIcon.png";
    return [self.baseURI URLByAppendingPathComponent:iconName];
}

- (NSString *)origin {
    return _origin ?: _URI.host;
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
