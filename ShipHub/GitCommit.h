//
//  Commit.h
//  ShipHub
//
//  Created by James Howard on 10/12/16.
//  Copyright © 2016 Real Artists, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <git2.h>

@interface GitCommit : NSObject

// - (id)initWithOID:(git_object *)obj; // Commit takes ownership of obj

@property (readonly) NSString *author;
@property (readonly) NSDate *date;
@property (readonly) NSString *message;

@end
