//
//  PopUpMetadataRowTemplate.h
//  Ship
//
//  Created by James Howard on 7/27/15.
//  Copyright (c) 2015 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol PopUpMetadataItem <NSObject>
@required
- (NSString *)identifier;
- (NSString *)name;
- (NSInteger)order;

@end

@interface PopUpMetadataRowTemplate : NSPredicateEditorRowTemplate

- (id)initWithMetadataType:(NSString *)item;

- (NSArray *)popUpItems; // returns array of objects conforming to PopUpMetadataItem.

- (NSString *)titleForPopUpItem:(id<PopUpMetadataItem>)item;

- (BOOL)showNotSetItem;

@end
