//
//  PLErrorManager.h
//  Plains
//
//  Created by Adam Demasi on 10/3/2022.
//

#import <Foundation/Foundation.h>
#import <Plains/Model/PLError.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 Objective-C wrapper for libapt's _error.

 @warning This class should only be accessed through its `sharedInstance`
 */
@interface PLErrorManager : NSObject

/*!
 Returns the shared `PLErrorManager` instance, creating it if necessary.

 @return The shared `PLErrorManager` instance.
 */
@property (nonatomic, strong, readonly, class) PLErrorManager *sharedInstance NS_SWIFT_NAME(shared);

/*!
 Error messages from libapt's `_error`

 @warning `_error` will be emptied as a result of this call.
 @return An array of strings representing warnings and errors that have occurred as a result of libapt's actions.
 */
@property (nonatomic, strong) NSArray <PLError *> *errorMessages;

/*!
 Returns the count of errors at the specified error level.

 @param errorLevel The error level
 @return The count of errors at the specified error level.
 */
- (NSUInteger)errorCountAtLevel:(PLErrorLevel)errorLevel;

/*!
 Clears all errors from libapt's internal `_error` and from our own errorMessages.

 @see errorMessages
 */
- (void)clear;

@end

NS_ASSUME_NONNULL_END
