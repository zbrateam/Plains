//
//  PLError.h
//  Plains
//
//  Created by Adam Demasi on 10/3/2022.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, PLErrorLevel) {
    PLErrorLevelWarning,
    PLErrorLevelError
};

@interface PLError : NSObject

@property (nonatomic) PLErrorLevel level;
@property (nonatomic, strong) NSString *text;

@end

NS_ASSUME_NONNULL_END
