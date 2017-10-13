//
//  NSViewController+PresentSaveError.m
//  Ship
//
//  Created by James Howard on 10/13/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "NSViewController+PresentSaveError.h"

#import "Error.h"
#import "Extras.h"

@implementation NSViewController (PresentSaveError)

- (void)presentSaveError:(NSError *)error withRetry:(dispatch_block_t)retry fail:(dispatch_block_t)fail
{
    NSAlert *alert = [NSAlert new];
    alert.alertStyle = NSCriticalAlertStyle;
    alert.messageText = NSLocalizedString(@"Unable to save changes", nil);
    alert.informativeText = [error localizedDescription] ?: @"";
    [alert addButtonWithTitle:NSLocalizedString(@"Retry", nil)];
    [alert addButtonWithTitle:NSLocalizedString(@"Discard Changes", nil)];
    
    id diagnostic = [error isShipError] ? error.userInfo[ShipErrorUserInfoErrorJSONBodyKey] : nil;
    
    if (diagnostic != nil) {
        NSButton *diagnosticButton = [alert addButtonWithTitle:NSLocalizedString(@"Copy Error", nil)];
        diagnosticButton.target = self;
        diagnosticButton.action = @selector(copyErrorDiagnostic:);
        diagnosticButton.extras_representedObject = diagnostic;
    }
    
    [alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == NSAlertFirstButtonReturn) {
            if (retry) retry();
        } else {
            if (fail) fail();
        }
    }];
}

- (IBAction)copyErrorDiagnostic:(id)sender {
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    [pboard clearContents];
    
    id diagnostic = [sender extras_representedObject];
    
    NSData *diagnosticData = [NSJSONSerialization dataWithJSONObject:diagnostic options:NSJSONWritingPrettyPrinted error:NULL];
    NSString *diagnosticStr = diagnosticData ? [[NSString alloc] initWithData:diagnosticData encoding:NSUTF8StringEncoding] : @"Missing Error Data";
    
    [pboard writeObjects:@[diagnosticStr]];
    
    [sender setTitle:NSLocalizedString(@"Copied!", nil)];
    [sender setEnabled:NO];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [sender setTitle:NSLocalizedString(@"Copy Error", nil)];
        [sender setEnabled:YES];
    });
}

@end
