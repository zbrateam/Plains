//
//  PLConfig.h
//  Plains
//
//  Created by Wilson Styres on 4/25/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface PLConfig : NSObject
+ (instancetype)sharedInstance;
- (void)setString:(NSString *)string forKey:(NSString *)key;
- (void)setBoolean:(BOOL)boolean forKey:(NSString *)key;
- (void)setInteger:(int)integer forKey:(NSString *)key;
- (NSString *)stringForKey:(NSString *)key;
- (BOOL)booleanForKey:(NSString *)key;
- (int)integerForKey:(NSString *)key;
@end

NS_ASSUME_NONNULL_END
