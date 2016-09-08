//
//  UserNotificationManager.h
//  ShipHub
//
//  Created by James Howard on 9/7/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UserNotificationManager : NSObject

+ (UserNotificationManager *)sharedManager;

- (void)applicationDidLaunch:(NSNotification *)note;

@end
