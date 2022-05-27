//
//  PlainsTests.m
//  PlainsTests
//
//  Created by Wilson Styres on 2/27/21.
//

#import <XCTest/XCTest.h>

#import <Plains/Plains.h>

#include <sys/stat.h>


@interface PlainsTests : XCTestCase
@end

@implementation PlainsTests

static PLConfig *config;

+ (void)setUp {
    NSString *cacheDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Caches/xyz.willy.Plains"];
    NSString *logDir = [cacheDir stringByAppendingPathComponent:@"logs"];
    NSString *listDir = [cacheDir stringByAppendingPathComponent:@"lists"];
    NSString *sourceParts = [cacheDir stringByAppendingPathComponent:@"sources.list.d"];
    [[NSFileManager defaultManager] createDirectoryAtPath:cacheDir withIntermediateDirectories:NO attributes:nil error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:logDir withIntermediateDirectories:NO attributes:nil error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:listDir withIntermediateDirectories:NO attributes:nil error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:sourceParts withIntermediateDirectories:NO attributes:nil error:nil];

    NSString *root = @"/opt/procursus";
    NSDictionary <NSString *, id> *configItems = @{
        @"Dir::Etc": [root stringByAppendingPathComponent:@"etc/apt"],
        @"Dir::Etc::sourceparts": sourceParts,
        @"Dir::State::status": [root stringByAppendingPathComponent:@"var/lib/dpkg/status"],
        @"Dir::dpkg::tupletable": [root stringByAppendingPathComponent:@"share/dpkg/tupletable"],
        @"Dir::dpkg::triplettable": [root stringByAppendingPathComponent:@"share/dpkg/triplettable"],
        @"Dir::dpkg::cputable": [root stringByAppendingPathComponent:@"share/dpkg/cputable"],
        @"Dir::Log": logDir,
        @"Dir::State::Lists": listDir,
        @"Dir::Cache": cacheDir,
        @"Dir::State": cacheDir,
        @"Dir::Bin::Dpkg": [root stringByAppendingPathComponent:@"libexec/zebra/supersling"],
        @"Plains::Slingshot": [root stringByAppendingPathComponent:@"libexec/zebra/supersling"],
        @"Plains::SourcesList": [cacheDir stringByAppendingPathComponent:@"plains.sources"],
        @"Acquire::AllowInsecureRepositories": @YES
    };

    config = [PLConfig sharedInstance];
    for (NSString *key in configItems.allKeys) {
        id value = configItems[key];
        if ([value isKindOfClass:NSNumber.class]) {
            [config setInteger:((NSNumber *)value).intValue forKey:key];
        } else {
            [config setString:value forKey:key];
        }
    }
    XCTAssertTrue([config initializeAPT]);
    [[PLPackageManager sharedInstance] import];
}

+ (void)tearDown {
    NSString *cacheDir = [config stringForKey:@"Dir::Cache"];
    [[NSFileManager defaultManager] removeItemAtPath:cacheDir error:nil];
}

- (void)testGenerateSourcesFile {
    PLSourceManager *sourceManager = [PLSourceManager sharedInstance];

    XCTAssertEqual([[sourceManager sources] count], 1);

    PLSource *source = sourceManager.sources.firstObject;
    XCTAssertEqual(source.type, @"deb");
    XCTAssertEqual(source.URI, [NSURL URLWithString:@"https://getzbra.com/repo/"]);
    XCTAssertEqual(source.suite, @"./");
    XCTAssertEqual(source.components, @[]);
}

- (void)testAddRemoveSource {
    NSString *type = @"deb";
    NSString *URI = @"https://repo.chariz.com/";
    NSString *distribution = @"./";
    
    PLSourceManager *sourceManager = [PLSourceManager sharedInstance];
    
    NSUInteger beforeCount = [[sourceManager sources] count];
    [sourceManager addSourceWithArchiveType:type repositoryURI:URI distribution:distribution components:nil];
    NSUInteger afterCount = [[sourceManager sources] count];
    
    XCTAssertEqual(beforeCount + 1, afterCount);

    for (PLSource *source in sourceManager.sources) {
        if ([[[source URI] absoluteString] isEqualToString:@"https://repo.chariz.com/"]) {
            [sourceManager removeSource:source];
            break;
        }
    }
    NSUInteger finalCount = [[sourceManager sources] count];
    
    XCTAssertEqual(beforeCount, finalCount);
}

@end
