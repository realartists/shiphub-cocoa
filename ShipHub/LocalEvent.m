//
//  LocalEvent.m
//  ShipHub
//
//  Created by James Howard on 3/14/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import "LocalEvent.h"
#import "LocalMilestone.h"

@implementation LocalEvent

- (id)computeCommitIdForProperty:(NSString *)propertyKey inDictionary:(NSDictionary *)d
{
    id v = d[@"commitId"];
    if (!v) v = d[@"sha"];
    if (!v) v = d[@"commit_id"];
    return v;
}

@end
