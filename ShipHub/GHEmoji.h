//
//  GHEmoji.h
//  Ship
//
//  Created by James Howard on 2/22/18.
//  Copyright © 2018 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (GHEmoji)

- (NSAttributedString *)githubEmojify;

@end

extern NSString *GHEmojiDidUpdateNotification; // sent when the emoji list is updated
extern NSString *GHEmojiUpdatedKey; // NSArray of NSStrings that have been updated
