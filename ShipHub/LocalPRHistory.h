//
//  LocalPRHistory.h
//  ShipHub
//
//  Created by James Howard on 5/24/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface LocalPRHistory : NSManagedObject

@property (nonatomic, strong) NSString *issueFullIdentifier;
@property (nonatomic, strong) NSString *sha;

@end
