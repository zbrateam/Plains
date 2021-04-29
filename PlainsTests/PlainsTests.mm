//
//  PlainsTests.m
//  PlainsTests
//
//  Created by Wilson Styres on 2/27/21.
//

#import <XCTest/XCTest.h>

#import <Plains/Plains.h>

#include <sys/stat.h>

@interface PlainsTests : XCTestCase {
    PLConfig *config;
}
@end

@implementation PlainsTests

- (void)setUp {
    NSString *cacheDir = [NSString stringWithFormat:@"%@/Library/Caches/xyz.willy.Plains", NSHomeDirectory()];
    NSString *logDir = [NSString stringWithFormat:@"%@/logs", cacheDir];
    NSString *listDir = [NSString stringWithFormat:@"%@/lists", cacheDir];
    mkdir(cacheDir.UTF8String, 0755);
    mkdir(logDir.UTF8String, 0755);
    mkdir(listDir.UTF8String, 0755);
    
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

- (void)tearDown {
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
