//
//  PRNavigationToolbarItem.h
//  ShipHub
//
//  Created by James Howard on 3/8/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "CustomToolbarItem.h"

@interface PRNavigationToolbarItem : CustomToolbarItem

@end

@interface NSObject (PRNavigationInformalProtocol)

- (IBAction)nextFile:(id)sender;
- (IBAction)previousFile:(id)sender;

- (IBAction)nextThing:(id)sender;
- (IBAction)previousThing:(id)sender;

- (IBAction)nextChange:(id)sender;
- (IBAction)previousChange:(id)sender;

- (IBAction)nextComment:(id)sender;
- (IBAction)previousComment:(id)sender;

@end
