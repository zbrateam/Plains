//
//  PLDownloadDelegate.h
//  Plains
//
//  Created by Adam Demasi on 8/3/2022.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol PLDownloadDelegate <NSObject>

- (void)addDownloadURL:(NSURL *)downloadURL withDestinationURL:(NSURL *)destinationURL forSourceUUID:(NSString *)sourceUUID;

@end

NS_ASSUME_NONNULL_END
