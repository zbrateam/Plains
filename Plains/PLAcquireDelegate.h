//
//  PLAcquireDelegate.h
//  Plains
//
//  Created by Wilson Styres on 4/9/21.
//

#import "apt-pkg/acquire.h"

#ifndef PLAcquireDelegate_h
#define PLAcquireDelegate_h

typedef NS_ENUM(NSUInteger, PLLogLevel) {
    PLLogLevelInfo,
    PLLogLevelStatus,
    PLLogLevelWarning,
    PLLogLevelError,
};

@protocol PLAcquireDelegate
- (void)startedDownloads;
- (void)statusUpdate:(NSString *)update atLevel:(PLLogLevel)level;
- (void)progressUpdate:(CGFloat)progress;
- (void)finishedDownloads;
@end

#endif /* PLAcquireDelegate_h */
