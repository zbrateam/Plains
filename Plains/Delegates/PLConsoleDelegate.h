//
//  PLConsoleDelegate.h
//  Plains
//
//  Created by Wilson Styres on 4/9/21.
//

#import <CoreGraphics/CoreGraphics.h>
#import "apt-pkg/acquire.h"

#ifndef PLAcquireDelegate_h
#define PLAcquireDelegate_h

typedef NS_ENUM(NSUInteger, PLLogLevel) {
    PLLogLevelInfo,
    PLLogLevelStatus,
    PLLogLevelWarning,
    PLLogLevelError,
};

@protocol PLConsoleDelegate
- (void)startedDownloads;
- (void)statusUpdate:(NSString *)update atLevel:(PLLogLevel)level;
- (void)finishUpdate:(NSString *)update;
- (void)progressUpdate:(CGFloat)progress;
- (void)finishedDownloads;
- (void)startedInstalls;
- (void)finishedInstalls;
@end

#endif /* PLAcquireDelegate_h */
