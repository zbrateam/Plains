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

/*!
 Constants to indicate the level of severity the message is sent as.
 */
typedef NS_ENUM(NSUInteger, PLLogLevel) {
    /*!
     Lowest level, background or debug information not important to the end-user.
     */
    PLLogLevelInfo,
    /*!
     Indicates a change in installation status, for example which package is currently being installed, or another important step that should be displayed to the user.
     */
    PLLogLevelStatus,
    /*!
     A warning that occurred as a result of actions performed by libapt. Should be displayed to the user but does not indicate that anything disastrous happened during an operation.
     */
    PLLogLevelWarning,
    /*!
     Highest level of severity. Usually indicates that a process failed and that the task as a whole cannot continue.
     */
    PLLogLevelError,
};

/*!
 Protocol to specify communication between libapt, Plains, and the frontend application.
 */
@protocol PLConsoleDelegate
/*!
 Called when `PLPackageManager` has started downloading packages.
 */
- (void)startedDownloads;

/*!
 Called when `PLPackageManager` has finished all downloads.
 */
- (void)finishedDownloads;

/*!
 Called when `PLPackageManager` has started installing or removing packages.
 */
- (void)startedInstalls;

/*!
 Called when `PLPackageManager` has finished installing or removing packages.
 */
- (void)finishedInstalls;

/*!
 Sends a message to the frontend application to be optionally displayed to the user based on its severity level.
 
 @param update Localized (if available) information to be displayed to the user.
 @param level Level of severity of the message.
 */
- (void)statusUpdate:(NSString *)update atLevel:(PLLogLevel)level;

/*!
 An action that is sent to the frontend application written to Plains' finish file descriptor.
 
 @warning This method will only be called if a dpkg trigger is fired that writes to the file descriptor indicated by `Plains::FinishFD::`
 */
- (void)finishUpdate:(NSString *)update;

/*!
 A progress update to the current overall download/installation process as reported by libapt.
 
 @param progress Floating point value indicating the current progress of the task. On a scale of 0 to 1.
 */
- (void)progressUpdate:(CGFloat)progress;
@end

#endif /* PLAcquireDelegate_h */
