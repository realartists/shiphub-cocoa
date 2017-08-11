//
//  RMEOpenController.m
//  ShipHub
//
//  Created by James Howard on 8/28/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "RMEOpenController.h"

#import "Extras.h"
#import "RMEDataStore.h"
#import "RMEDocumentController.h"

@interface RMEOpenController ()

@property IBOutlet NSTextField *issueIdentifierField;

@end

@implementation RMEOpenController

- (NSNibName)windowNibName { return @"RMEOpenController"; }

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (IBAction)open:(id)sender {
    NSString *issueIdentifier = [[_issueIdentifierField stringValue] trim];
    
    RMEDocumentController *docController = [RMEDocumentController sharedDocumentController];
    [docController openDiffWithIdentifier:issueIdentifier canOpenExternally:NO scrollInfo:nil completion:nil];
}

- (IBAction)cancel:(id)sender {
    [self close];
}

@end
