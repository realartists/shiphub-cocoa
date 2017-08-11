//
//  IssueNotification.h
//  ShipHub
//
//  Created by James Howard on 9/7/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#if TARGET_SHIP
@class LocalNotification;
#endif

@interface IssueNotification : NSObject

#if TARGET_SHIP
- (instancetype)initWithLocalNotification:(LocalNotification *)ln;
#endif

@property (nonatomic, retain) NSNumber *commentIdentifier;
@property (nonatomic, retain) NSString *reason;
@property (nonatomic, retain) NSNumber *identifier;
@property (nonatomic, retain) NSDate *updatedAt;
@property (nonatomic, retain) NSDate *lastReadAt;
@property (nonatomic, getter=isUnread) BOOL unread;

@end
