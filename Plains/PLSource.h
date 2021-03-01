//
//  PLSource.h
//  Plains
//
//  Created by Wilson Styres on 3/1/21.
//

#import <Foundation/Foundation.h>

typedef struct metaIndex metaIndex; // Some sort of tricky forward declaring metaIndex because theos doesn't like #include

NS_ASSUME_NONNULL_BEGIN

@interface PLSource : NSObject
@property NSURL *URI;
@property NSString *distribution;
@property NSString *type;
@property NSString *origin;
@property NSString *label;
@property NSString *version;
@property NSString *codename;
@property NSString *suite;
@property NSString *releaseNotes;
@property short defaultPin;
@property BOOL trusted;
- (id)initWithMetaIndex:(metaIndex *)index;
@end

NS_ASSUME_NONNULL_END
