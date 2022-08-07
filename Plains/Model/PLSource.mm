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
#import "PLTagFile.h"
#import "NSString+Plains.h"
#import <Plains/Plains-Swift.h>
#import <sys/stat.h>

PL_APT_PKG_IMPORTS_BEGIN
#include <apt-pkg/metaindex.h>
#include <apt-pkg/debmetaindex.h>
#include <apt-pkg/acquire.h>
#include <apt-pkg/acquire-item.h>
#include <apt-pkg/configuration.h>
#include <apt-pkg/strutl.h>
#include <apt-pkg/fileutl.h>
PL_APT_PKG_IMPORTS_END

@implementation PLSource {
    NSDictionary <NSString *, NSNumber *> *_sections;
    PLTagFile *_tagSection;
}

- (instancetype)initWithMetaIndex:(metaIndex *)index {
    self = [super init];
    
    if (self) {
        _index = index;

        NSString *URIString = [NSString plains_stringWithStdString:index->GetURI()];
        if (URIString) {
            _URI = [NSURL URLWithString:URIString];
        }

        // Get an index target for this source. We just need the first one of matching type, since
        // we only care about grabbing the base URI, which contains the dist but not the component.
        std::string baseURI;
        for (IndexTarget target : index->GetIndexTargets()) {
            if (strcmp(index->GetType(), target.Option(IndexTarget::TARGET_OF).c_str()) == 0) {
                std::string baseURI2 = target.Option(IndexTarget::BASE_URI);
                if (!baseURI2.empty()) {
                    baseURI = baseURI2;
                    URIString = [NSString plains_stringWithStdString:baseURI];
                    break;
                }
            }
        }

        std::string uuid = URItoFileName(baseURI);
        _UUID = [NSString plains_stringWithStdString:uuid];
        _baseURI = [NSURL URLWithString:URIString];

        NSMutableArray *components = [NSMutableArray array];
        NSMutableArray *architectures = [NSMutableArray array];
        for (IndexTarget target : index->GetIndexTargets()) {
            if (strcmp(index->GetType(), target.Option(IndexTarget::TARGET_OF).c_str()) == 0) {
                std::string component = target.Option(IndexTarget::COMPONENT);
                if (!component.empty()) {
                    NSString *value = [NSString plains_stringWithStdString:component];
                    if (![components containsObject:value]) {
                        [components addObject:value];
                    }
                }

                std::string arch = target.Option(IndexTarget::ARCHITECTURE);
                if (!arch.empty()) {
                    NSString *value = [NSString plains_stringWithStdString:arch];
                    if (![architectures containsObject:value]) {
                        [architectures addObject:value];
                    }
                }
            }
        }
        _components = components;
        _architectures = architectures;

        debReleaseIndex *releaseIndex = (debReleaseIndex *)index;
        if (releaseIndex) {
            std::string listsDir = _config->FindDir("Dir::State::lists");
            std::string releaseFilePath = listsDir + uuid + "Release";
            std::string errorText;

            // We use stat() here because FileFd.Open() will spit out annoying warnings to _error
            // if the file doesn’t exist.
            FileFd releaseFd;
            if ((stat(releaseFilePath.c_str(), NULL) == 0 || errno != ENOENT) && releaseFd.Open(releaseFilePath, FileFd::ReadOnly)) {
                _index->Load(releaseFilePath, &errorText);

                if (errorText.empty()) {
                    _tagSection = [[PLTagFile alloc] initWithURL:[NSURL fileURLWithPath:[NSString plains_stringWithStdString:releaseFilePath]]];
                }
            }

            debReleaseIndexPrivate *privateIndex = releaseIndex->d;
            std::vector<debReleaseIndexPrivate::debSectionEntry> entries = privateIndex->DebEntries;

            for (debReleaseIndexPrivate::debSectionEntry entry : entries) {
                std::string entryPath = entry.sourcesEntry;
                if (!entryPath.empty()) {
                    NSString *filePath = [NSString stringWithUTF8String:entryPath.c_str()];
                    NSArray *components = [filePath componentsSeparatedByString:@":"];
                    _entryFilePath = components[0];
                }
            }
        }
    }
    
    return self;
}

#pragma mark - Fields

- (NSString *)getField:(NSString *)field {
    return _tagSection[field];
}

- (NSString *)distribution {
    return [NSString plains_stringWithStdString:_index->GetDist()];
}

- (NSString *)type {
    return [NSString plains_stringWithStdString:_index->GetType()];
}

- (NSString *)version {
    return [NSString plains_stringWithStdString:_index->GetVersion()];
}

- (NSString *)codename {
    return [NSString plains_stringWithStdString:_index->GetCodename()];
}

- (NSString *)suite {
    return [NSString plains_stringWithStdString:_index->GetSuite()];
}

- (NSString *)releaseNotes {
    return [NSString plains_stringWithStdString:_index->GetReleaseNotes()];
}

- (short)defaultPin {
    return _index->GetDefaultPin();
}

- (BOOL)isTrusted {
    return _index->IsTrusted();
}

- (NSURL *)iconURL {
    NSString *arch = self.architectures.firstObject ?: [[PLConfig sharedInstance] stringForKey:@"APT::Architecture"];
    NSString *iconName = [arch isEqualToString:@"iphoneos-arm"] ? @"CydiaIcon.png" : @"RepoIcon.png";
    return [self.baseURI URLByAppendingPathComponent:iconName];
}

- (NSString *)origin {
    return [self getField:@"Origin"] ?: [self getField:@"Label"] ?: _URI.host;
}

- (NSDictionary *)sections {
    if (!_sections || _sections.count == 0) {
        NSArray <PLPackage *> *packages = [[PLSourceManager sharedInstance] packagesForSource:self];
        NSMutableDictionary *tempSections = [NSMutableDictionary new];
        
        for (PLPackage *package in packages) {
            NSString *sectionName = package.section.plains_cleanedSectionName;
            NSString *sectionKey = sectionName ?: @"Uncategorized";
            
            NSNumber *count = tempSections[sectionKey];
            if (count) {
                tempSections[sectionKey] = @(count.unsignedIntegerValue + 1);
            } else {
                tempSections[sectionKey] = @(1);
            }
        }
        _sections = tempSections;
    }
    return _sections;
}

- (BOOL)isEqual:(PLSource *)other {
    if (other == self) {
        return YES;
    }
    return [self.type isEqualToString:other.type] && [self.URI isEqual:other.URI] && [self.distribution isEqualToString:other.distribution] && [self.components isEqualToArray:other.components];
}

@end
