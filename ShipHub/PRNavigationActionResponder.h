//
//  PRNavigationActionResponder.h
//  ShipHub
//
//  Created by James Howard on 7/26/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol PRNavigationActionResponder <NSObject>

- (IBAction)nextFile:(id)sender;
- (IBAction)previousFile:(id)sender;

- (IBAction)nextThing:(id)sender;
- (IBAction)previousThing:(id)sender;

- (IBAction)nextChange:(id)sender;
- (IBAction)previousChange:(id)sender;

- (IBAction)nextComment:(id)sender;
- (IBAction)previousComment:(id)sender;

@end
