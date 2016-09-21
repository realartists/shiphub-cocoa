//
//  AvatarManager.h
//  ShipHub
//
//  Created by James Howard on 9/20/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AvatarManager : NSObject

+ (instancetype)activeManager; // don't cache this as it can change

// Returns an image that progressively gains representations
- (NSImage *)imageForAccountIdentifier:(NSNumber *)accountIdentifier avatarURL:(NSURL *)avatarURL;

@end

extern NSString *const AvatarImageDidUpdateNotification; // sent by an avatar NSImage instance when it gains a representation

@interface AvatarImageView : NSImageView

@end
