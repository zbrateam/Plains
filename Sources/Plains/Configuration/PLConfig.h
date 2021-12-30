//
//  PLConfig.h
//  Plains
//
//  Created by Wilson Styres on 4/25/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 Objective-C wrapper for libapt's _config. Used to set various configuration options provided by libapt.
 
 @warning This class should only be accessed through its `sharedInstance`
 */
@interface PLConfig : NSObject {
    NSMutableArray *errorMessages;
}

/*!
 Returns the shared `PLConfig` instance, creating it if necessary.
 
 @return The shared `PLConfig` instance.
 */
+ (instancetype)sharedInstance;

/*!
 Clears all errors from libapt's internal `_error` and from our own errorMessages.
 
 @see errorMessages
 */
- (void)clearErrors;

/*!
 Error messages from libapt's `_error`
 
 @warning `_error` will be emptied as a result of this call.
 @return An array of strings representing warnings and errors that have occurred as a result of libapt's actions.
 */
- (NSArray <NSString *> *)errorMessages;

/*!
 Retrieve a string value from the current configuration.
 
 @param key The key to search for.
 @return The value stored by `key` or `NULL` if no value is set.
 */
- (NSString *_Nullable)stringForKey:(NSString *)key;

/*!
 Save a string into `_config`
 
 @param key The key to represent `string`. If the key has two colons as a suffix, it will be appended to the tree represented by `key`.
 @param string The value to be saved into `_config`.
 */
- (void)setString:(NSString *)string forKey:(NSString *)key;

/*!
 Retrieve a boolean value from the current configuration.
 
 @param key The key to search for.
 @return The value stored by `key` or `false` if no value is set.
 */
- (BOOL)booleanForKey:(NSString *)key;

/*!
 Save a boolean value into `_config`
 
 @param key The key to represent `boolean`. If the key has two colons as a suffix, it will be appended to the tree represented by `key`.
 @param boolean The value to be saved into `_config`.
 */
- (void)setBoolean:(BOOL)boolean forKey:(NSString *)key;

/*!
 Retrieve an integer value from the current configuration.
 
 @param key The key to search for.
 @return The value stored by `key` or `0` if no value is set.
 */
- (int)integerForKey:(NSString *)key;

/*!
 Save an integer value into `_config`
 
 @param key The key to represent `integer`. If the key has two colons as a suffix, it will be appended to the tree represented by `key`.
 @param integer The value to be saved into `_config`.
 */
- (void)setInteger:(int)integer forKey:(NSString *)key;
@end

NS_ASSUME_NONNULL_END
