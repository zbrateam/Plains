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
@property NSArray *sections;
@property short defaultPin;
@property BOOL trusted;
@property metaIndex *index;
+ (UIImage *)imageForSection:(NSString *)section;
- (id)initWithMetaIndex:(metaIndex *)index;
- (NSURL *)iconURL;
@end

NS_ASSUME_NONNULL_END
