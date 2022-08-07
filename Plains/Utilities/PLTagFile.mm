//
//  PLTagFile.m
//  Plains
//
//  Created by Adam Demasi on 27/6/2022.
//

#import "PLTagFile.h"
#import <NSString+Plains.h>

PL_APT_PKG_IMPORTS_BEGIN
#include <apt-pkg/fileutl.h>
#include <apt-pkg/tagfile.h>
PL_APT_PKG_IMPORTS_END

@implementation PLTagFile {
    pkgTagSection _tagSection;
}

- (instancetype)initWithURL:(NSURL *)url {
    FileFd fd;
    if (!fd.Open(url.path.UTF8String, FileFd::ReadOnly)) {
        return nil;
    }

    self = [super init];
    if (self) {
        pkgTagFile *tagFile = new pkgTagFile(&fd);
        tagFile->Step(_tagSection);
    }
    return self;
}

- (nullable NSString *)objectForKeyedSubscript:(NSString *)key {
    return [NSString plains_stringWithStdString:_tagSection.FindS(key.UTF8String)];
}

@end
