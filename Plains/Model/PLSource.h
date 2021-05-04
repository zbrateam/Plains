//
//  PLSource.h
//  Plains
//
//  Created by Wilson Styres on 3/1/21.
//

#import <Foundation/Foundation.h>

@class UIImage;

typedef struct metaIndex metaIndex; // Some sort of tricky forward declaring metaIndex because theos doesn't like #include

NS_ASSUME_NONNULL_BEGIN

@interface PLSource : NSObject
@property NSString *UUID;
@property NSURL *baseURI;
@property NSURL *URI;
@property NSString *distribution;
@property NSString *type;
@property (nonatomic) NSString *origin;
@property NSString *label;
@property NSString *version;
@property NSString *codename;
@property NSString *suite;
@property NSString *releaseNotes;
@property (readonly) NSDictionary *sections;
@property short defaultPin;
@property BOOL trusted;
@property BOOL remote;
@property metaIndex *index;
@property NSString *entryFilePath;
@property NSArray *components;
@property NSArray *messages;
+ (UIImage *)imageForSection:(NSString *)section;
- (id)initWithMetaIndex:(metaIndex *)index;
- (NSURL *)iconURL;
- (BOOL)canRemove;
- (BOOL)isEqualToSource:(PLSource *)other;
- (NSComparisonResult)compareByOrigin:(PLSource *)other;
@end

NS_ASSUME_NONNULL_END
