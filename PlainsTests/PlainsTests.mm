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
    mkdir("/Users/wstyres/Library/Caches/xyz.willy.Plains", 0755);
    mkdir("/Users/wstyres/Library/Caches/xyz.willy.Plains/logs", 0755);
    mkdir("/Users/wstyres/Library/Caches/xyz.willy.Plains/lists", 0755);
    
    config = [PLConfig sharedInstance];
    
    [config setBoolean:YES forKey:@"Acquire::AllowInsecureRepositories"];
    [config setString:@"/Users/wstyres/Library/Caches/xyz.willy.Plains/logs" forKey:@"Dir::Log"];
    [config setString:@"/Users/wstyres/Library/Caches/xyz.willy.Plains/lists" forKey:@"Dir::State::Lists"];
    [config setString:@"/Users/wstyres/Library/Caches/xyz.willy.Plains/" forKey:@"Dir::Cache"];
    [config setString:@"/Users/wstyres/Library/Caches/xyz.willy.Plains/" forKey:@"Dir::State"];
    [config setString:@"/opt/procursus/libexec/zebra/supersling" forKey:@"Dir::Bin::dpkg"];
    [config setString:@"/opt/procursus/libexec/zebra/supersling" forKey:@"Plains::Slingshot"];
    [config setString:@"/Users/wstyres/Library/Caches/xyz.willy.Plains/plains.sources" forKey:@"Plains::SourcesList"];
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtPath:@"/Users/wstyres/Library/Caches/xyz.willy.Plains/" error:nil];
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
