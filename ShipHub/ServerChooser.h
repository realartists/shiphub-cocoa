//
//  ServerChooser.h
//  ShipHub
//
//  Created by James Howard on 7/25/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol ServerChooserDelegate;

@interface ServerChooser : NSViewController

@property (weak) id<ServerChooserDelegate> delegate;

@property (nonatomic, copy) NSString *ghHostValue;
@property (nonatomic, copy) NSString *shipHostValue;

@end

@protocol ServerChooserDelegate <NSObject>

- (void)serverChooser:(ServerChooser *)chooser didChooseShipHost:(NSString *)shipHost ghHost:(NSString *)ghHost;
- (void)serverChooserDidCancel:(ServerChooser *)chooser;

@end