//
//  PLTagFile.h
//  Plains
//
//  Created by Adam Demasi on 27/6/2022.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TagFile)
@interface PLTagFile : NSObject

- (instancetype)initWithURL:(NSURL *)url;

- (nullable NSString *)objectForKeyedSubscript:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
