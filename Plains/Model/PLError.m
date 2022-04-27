//
//  PLError.m
//  Plains
//
//  Created by Adam Demasi on 10/3/2022.
//

#import "PLError.h"

@implementation PLError

+ (NSString *)stringForErrorLevel:(PLErrorLevel)errorLevel {
    switch (errorLevel) {
    case PLErrorLevelWarning: return @"Warning";
    case PLErrorLevelError:   return @"Error";
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"PLError: %@: %@", [self.class stringForErrorLevel:self.level], self.text];
}

@end
