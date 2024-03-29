//
//  PLConfig.h
//  Plains
//
//  Created by Wilson Styres on 4/25/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/*!
 Objective-C wrapper for libapt's `_config`. Used to set various configuration options provided by libapt.
 
 > Warning: This class should only be accessed through its `sharedInstance`.
 */
NS_SWIFT_NAME(PlainsConfig)
@interface PLConfig : NSObject

/*!
 Returns the shared `PLConfig` instance, creating it if necessary.
 
 - returns: The shared `PLConfig` instance.
 */
@property (nonatomic, strong, readonly, class) PLConfig *sharedInstance NS_SWIFT_NAME(shared);

/*!
 Initialize libapt.

 - returns: Whether APT was successfully initialized.
 */
- (BOOL)initializeAPT;

/*!
 Retrieve a string value from the current configuration.
 
 - parameter key: The key to search for.
 - returns: The value stored by `key` or `NULL` if no value is set.
 */
- (nullable NSString *)stringForKey:(NSString *)key NS_SWIFT_NAME(string(forKey:));

/*!
 Retrieve a URL value from the current configuration.

 - parameter key: The key to search for.
 - returns: The NSURL representation of the string stored by `key` or `NULL` if no value is set.
 */
- (nullable NSURL *)fileURLForKey:(NSString *)key NS_SWIFT_NAME(fileURL(forKey:));

/*!
 Retrieve an array of string values from the current configuration.

 - parameter key: The key to search for.
 - returns: The value stored by `key` or `NULL` if no value is set.
 */
- (nullable NSArray <NSString *> *)arrayForKey:(NSString *)key NS_SWIFT_NAME(array(forKey:));

/*!
 Save a string into `_config`.
 
 - parameter key: The key to represent `string`. If the key has two colons as a suffix, it will be
   appended to the tree represented by `key`.
 - parameter string: The value to be saved into `_config`.
 */
- (void)setString:(NSString *)string forKey:(NSString *)key NS_SWIFT_NAME(set(string:forKey:));

/*!
 Retrieve a boolean value from the current configuration.
 
 - parameter key: The key to search for.
 - returns: The value stored by `key` or `false` if no value is set.
 */
- (BOOL)booleanForKey:(NSString *)key NS_SWIFT_NAME(boolean(forKey:));

/*!
 Save a boolean value into `_config`.
 
 - parameter key: The key to represent `boolean`. If the key has two colons as a suffix, it will be
   appended to the tree represented by `key`.
 - parameter boolean: The value to be saved into `_config`.
 */
- (void)setBoolean:(BOOL)boolean forKey:(NSString *)key NS_SWIFT_NAME(set(boolean:forKey:));

/*!
 Retrieve an integer value from the current configuration.
 
 - parameter key: The key to search for.
 - returns: The value stored by `key` or `0` if no value is set.
 */
- (int)integerForKey:(NSString *)key NS_SWIFT_NAME(integer(forKey:));

/*!
 Save an integer value into `_config`.
 
 - parameter key: The key to represent `integer`. If the key has two colons as a suffix, it will be
   appended to the tree represented by `key`.
 - parameter integer: The value to be saved into `_config`.
 */
- (void)setInteger:(int)integer forKey:(NSString *)key NS_SWIFT_NAME(set(integer:forKey:));

/*!
 Remove a value from `_config`.

 - parameter key: The key to be removed from `_config`.
 */
- (void)removeObjectForKey:(NSString *)key;

/*!
 Retrieve the list of compression types supported by APT, sorted by preferred order.
 */
@property (nonatomic, strong, readonly) NSArray <NSString *> *compressionTypes;

/*!
 Retrieve the list of architectures supported by APT.
 */
@property (nonatomic, strong, readonly) NSArray <NSString *> *architectures;

@end

NS_ASSUME_NONNULL_END
