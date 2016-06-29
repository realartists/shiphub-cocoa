//
//  NSFileWrapper+ImageExtras.m
//  ShipHub
//
//  Created by James Howard on 6/29/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "NSFileWrapper+ImageExtras.h"
#import "Extras.h"

#import <objc/runtime.h>

@implementation NSFileWrapper (ImageExtras)

static const char *ObjKey = "ImageExtras";

- (NSImage *)image {
    NSImage *image = objc_getAssociatedObject(self, ObjKey);
    if (image) return image;
    if ([self isImageType]) {
        image = [[NSImage alloc] initWithData:self.regularFileContents];
        objc_setAssociatedObject(self, ObjKey, image, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return image;
}

@end
