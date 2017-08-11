//
//  RMEDataModelHistoryItem.h
//  Reviewed By Me
//
//  Created by James Howard on 12/7/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface RMEDataModelHistoryItem : NSManagedObject

@property (nonatomic, readwrite, strong) NSString *issueIdentifier;
@property (nonatomic, readwrite, strong) NSString *issueTitle;
@property (nonatomic, readwrite, strong) NSDate *lastViewedAt;
@property (nonatomic, readwrite, strong) NSString *lastViewedSha;

@end
