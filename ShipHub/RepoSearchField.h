//
//  RepoSearchField.h
//  ShipHub
//
//  Created by James Howard on 7/19/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Auth;
@class AvatarManager;

@interface RepoSearchField : NSTextField

@property Auth *auth;
@property AvatarManager *avatarManager;

@end
