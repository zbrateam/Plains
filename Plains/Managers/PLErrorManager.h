//
//  PLErrorManager.h
//  Plains
//
//  Created by Adam Demasi on 10/3/2022.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, PLErrorLevel) {
    PLErrorLevelWarning,
    PLErrorLevelError
} NS_SWIFT_NAME(ErrorLevel);

@class PLError;

NS_ASSUME_NONNULL_BEGIN

/*!
 Objective-C wrapper for libapt's _error.

 - warning: This class should only be accessed through its `sharedInstance`
 */
NS_SWIFT_NAME(ErrorManager)
@interface PLErrorManager : NSObject

/*!
 Returns the shared `PLErrorManager` instance, creating it if necessary.

 - returns: The shared `PLErrorManager` instance.
 */
@property (nonatomic, strong, readonly, class) PLErrorManager *sharedInstance NS_SWIFT_NAME(shared);

/*!
 Error messages from libapt's `_error`

 - warning: `_error` will be emptied as a result of this call.
 - returns: An array of strings representing warnings and errors that have occurred as a result of libapt's actions.
 */
@property (nonatomic, strong) NSArray <PLError *> *errorMessages;

/*!
 Returns the count of errors at the specified error level.

 - parameter errorLevel: The error level
 - returns: The count of errors at the specified error level.
 */
- (NSUInteger)errorCountAtLevel:(PLErrorLevel)errorLevel;

/*!
 Clears all errors from libapt's internal `_error` and from our own errorMessages.

 - seealso: ``PLErrorManager/errorMessages``
 */
- (void)clear;

@end

NS_ASSUME_NONNULL_END
