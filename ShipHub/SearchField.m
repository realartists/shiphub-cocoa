//
//  SearchField.m
//  Ship
//
//  Created by James Howard on 6/9/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import "SearchField.h"

// https://gist.github.com/Kapeli/7abd83d966957c17a827
@implementation SearchField

// 2. To fix cursor not blinking when the search field becomes first responder,
// subclass NSSearchField and add:

- (BOOL)becomeFirstResponder
{
    BOOL result = [super becomeFirstResponder];
    if(result)
    {
        [self ensureCursorBlink];
    }
    return result;
}

- (void)selectText:(id)sender
{
    [self ensureCursorBlink];
    [super selectText:sender];
}

- (void)ensureCursorBlink
{
    static BOOL isYosemite;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        isYosemite = [[NSProcessInfo processInfo] operatingSystemVersion].minorVersion == 10;
    });
    if(isYosemite && !self.stringValue.length)
    {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if(!self.stringValue.length)
            {
                [self setStringValue:@" "];
                [self setStringValue:@""];
            }
        });
    }
}
@end
