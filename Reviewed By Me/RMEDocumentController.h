//
//  PRDocumentController.h
//  ShipHub
//
//  Created by James Howard on 8/10/17.
//  Copyright © 2017 Real Artists, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PRDocument;

@interface RMEDocumentController : NSDocumentController

- (void)openDiffWithIdentifier:(id)issueIdentifier canOpenExternally:(BOOL)canOpenExternally scrollInfo:(NSDictionary *)scrollInfo completion:(void (^)(PRDocument *doc))completion;

- (IBAction)newPullRequest:(id)sender;

@end
