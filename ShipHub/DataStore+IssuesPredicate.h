//
//  DataStore+IssuesPredicate.h
//  Ship
//
//  Created by James Howard on 12/29/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import "DataStore.h"

@interface DataStore (IssuesPredicate)

- (NSPredicate *)issuesPredicate:(NSPredicate *)basePredicate moc:(NSManagedObjectContext *)moc;

@end
