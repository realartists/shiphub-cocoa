//
//  LabelsControl.h
//  ShipHub
//
//  Created by James Howard on 5/9/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Label;

@interface LabelsControl : NSControl

@property (nonatomic) NSArray<Label *> *labels;

+ (void)drawLabels:(NSArray<Label *> *)labels
            inRect:(CGRect)b
       highlighted:(BOOL)highlighted
   backgroundColor:(NSColor *)backgroundColor;

+ (CGSize)sizeLabels:(NSArray<Label *> *)labels;

@end

