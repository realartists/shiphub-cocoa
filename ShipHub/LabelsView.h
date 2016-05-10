//
//  LabelsView.h
//  ShipHub
//
//  Created by James Howard on 5/9/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Label;

@interface LabelsView : NSView

@property (nonatomic) NSArray<Label *> *labels;

@property (nonatomic, getter=isHighlighted) BOOL highlighted;

@end
