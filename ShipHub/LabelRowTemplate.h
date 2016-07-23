//
//  LabelRowTemplate.h
//  ShipHub
//
//  Created by James Howard on 7/24/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LabelRowTemplate : NSPredicateEditorRowTemplate

// for subclassers
- (NSPopUpButton *)popUp;

@end
