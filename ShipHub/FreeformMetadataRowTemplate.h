//
//  FreeformMetadataRowTemplate.h
//  Ship
//
//  Created by James Howard on 7/27/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CompletingTextField;

@interface FreeformMetadataRowTemplate : NSPredicateEditorRowTemplate

- (id)initWithLeftExpressions:(NSArray *)leftExpressions;

- (NSArray *)complete:(NSString *)text;
- (NSString *)valueWithIdentifier:(NSString *)identifier;
- (NSString *)identifierWithValue:(NSString *)value;

- (CompletingTextField *)textField;

@end
