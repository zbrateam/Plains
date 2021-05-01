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
    NSString *cacheDir = [NSString stringWithFormat:@"%@/Library/Caches/xyz.willy.Plains", NSHomeDirectory()];
    NSString *logDir = [NSString stringWithFormat:@"%@/logs", cacheDir];
    NSString *listDir = [NSString stringWithFormat:@"%@/lists", cacheDir];
    [[NSFileManager defaultManager] createDirectoryAtPath:cacheDir withIntermediateDirectories:NO attributes:nil error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:logDir withIntermediateDirectories:NO attributes:nil error:nil];
    [[NSFileManager defaultManager] createDirectoryAtPath:listDir withIntermediateDirectories:NO attributes:nil error:nil];
    
    config = [PLConfig sharedInstance];
    
    [config setBoolean:YES forKey:@"Acquire::AllowInsecureRepositories"];
    [config setString:logDir forKey:@"Dir::Log"];
    [config setString:listDir forKey:@"Dir::State::Lists"];
    [config setString:cacheDir forKey:@"Dir::Cache"];
    [config setString:cacheDir forKey:@"Dir::State"];
    [config setString:@"/opt/procursus/libexec/zebra/supersling" forKey:@"Dir::Bin::dpkg"];
    [config setString:@"/opt/procursus/libexec/zebra/supersling" forKey:@"Plains::Slingshot"];
    [config setString:[cacheDir stringByAppendingPathComponent:@"plains.sources"] forKey:@"Plains::SourcesList"];
}

+ (void)tearDown {
    NSString *cacheDir = [config stringForKey:@"Dir::Cache"];
    [[NSFileManager defaultManager] removeItemAtPath:cacheDir error:nil];
}

- (void)testAddSource {
    NSString *type = @"deb";
    NSString *URI = @"https://repo.chariz.com/";
    NSString *distribution = @"./";
    
    PLSourceManager *sourceManager = [PLSourceManager sharedInstance];
    
    NSUInteger beforeCount = [[sourceManager sources] count];
    [sourceManager addSourceWithArchiveType:type repositoryURI:URI distribution:distribution components:nil];
    NSUInteger afterCount = [[sourceManager sources] count];
    
    XCTAssertEqual(beforeCount + 1, afterCount);
}

- (void)testRemoveSource {
    PLSourceManager *sourceManager = [PLSourceManager sharedInstance];
    
    NSUInteger beforeCount = [[sourceManager sources] count];
    for (PLSource *source in sourceManager.sources) {
        if ([[[source URI] absoluteString] isEqualToString:@"https://repo.chariz.com/"]) {
            [sourceManager removeSource:source];
            break;
        }
    }
    NSUInteger afterCount = [[sourceManager sources] count];
    
    XCTAssertEqual(beforeCount - 1, afterCount);
}

@end
