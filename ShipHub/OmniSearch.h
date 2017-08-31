//
//  OmniSearch.h
//  ShipHub
//
//  Created by James Howard on 8/29/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol OmniSearchDelegate;
@class OmniSearchItem;

@interface OmniSearch : NSWindowController

@property (nonatomic, copy) NSString *queryString;
@property (nonatomic, copy) NSString *placeholderString;

@property (weak) id<OmniSearchDelegate> delegate;

- (void)reloadData;

@end

@interface OmniSearchItem : NSObject

@property NSString *title;
@property NSImage *image;
@property id representedObject;

@end

@protocol OmniSearchDelegate <NSObject>

- (void)omniSearch:(OmniSearch *)searchController itemsForQuery:(NSString *)query completion:(void (^)(NSArray<OmniSearchItem *> *items))completion;

- (void)omniSearch:(OmniSearch *)searchController didSelectItem:(OmniSearchItem *)item;

@end
