//
//  SendErrorEmail.m
//  ShipHub
//
//  Created by James Howard on 7/23/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "SendErrorEmail.h"

#import "Extras.h"

void SendErrorEmail(NSString *subject, NSString *body, NSString *attachmentPath) {
    NSURL *scriptURL = [[NSBundle mainBundle] URLForResource:@"SendErrorEmail" withExtension:@"scpt"];
    
    NSDictionary *asError = nil;
    NSAppleScript *as = [[NSAppleScript alloc] initWithContentsOfURL:scriptURL error:&asError];
    
    NSError *scriptError = [NSAppleScript errorWithErrorDictionary:asError];
    
    if (scriptError) {
        ErrLog(@"%@", scriptError);
        return;
    }
    
    NSArray *params = @[ subject, body, attachmentPath ];
    
    scriptError = [as callSubroutine:@"do_mail" withParams:params];
    
    if (scriptError) {
        ErrLog(@"%@", scriptError);
    }
}
